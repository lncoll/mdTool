unit ImgFetch;

{ Descarga asíncrona de imágenes remotas (http/https) para el visor,
  con caché en disco.

  Diseño a prueba de interbloqueos: el hilo de descarga solo escribe
  ficheros (destino o marcador .failed) y termina; el hilo principal
  recoge los resultados con un TTimer. Nunca hay Synchronize, WaitFor
  ni Free cruzados entre hilos (eso colgaba la app). }

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, ExtCtrls;

type
  TImageFetchedEvent = procedure(const Url: string; Success: Boolean) of object;

  TImageFetcher = class
  private
    FCacheDir: string;
    FTimer: TTimer;
    FStreams: TStringList; { url -> TMemoryStream (propios, reutilizados) }
    FInFlight: TStringList; { urls descargándose ahora mismo }
    FFailed: TStringList;   { urls fallidas en esta sesión (no reintentar) }
    FOnFetched: TImageFetchedEvent;
    function FailFileFor(const Url: string): string;
    procedure StartDownload(const Url: string);
    procedure TimerTick(Sender: TObject);
  public
    constructor Create(const ACacheDir: string);
    destructor Destroy; override;
    { True + Stream si está en caché (el Stream sigue siendo del fetcher,
      no liberarlo; se devuelve posicionado al inicio). False si se ha
      encolado la descarga o la URL ya falló (o no es http/https). }
    function GetImageStream(const Url: string; out Stream: TStream): Boolean;
    function IsPending(const Url: string): Boolean;
    function CacheFileFor(const Url: string): string;
    property CacheDir: string read FCacheDir;
    property OnFetched: TImageFetchedEvent
      read FOnFetched write FOnFetched;
  end;

implementation

uses
  md5, fphttpclient, opensslsockets;

type
  TImageDownloadThread = class(TThread)
  private
    FUrl, FFile, FFailFile: string;
  protected
    procedure Execute; override;
  public
    constructor Create(const AUrl, AFile: string);
  end;

const
  IMG_EXTS: array[0..6] of string =
    ('.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp', '.svg');

{ TImageDownloadThread }

constructor TImageDownloadThread.Create(const AUrl, AFile: string);
begin
  inherited Create(True);
  FreeOnTerminate := True; // se libera solo; nadie lo toca desde fuera
  FUrl := AUrl;
  FFile := AFile;
  FFailFile := AFile + '.failed';
end;

procedure TImageDownloadThread.Execute;
var
  Http: TFPHTTPClient;
  FS: TFileStream;
  CT, Tmp: string;
  OK: Boolean;
begin
  OK := False;
  Tmp := FFile + '.part';
  try
    DeleteFile(Tmp);
    DeleteFile(FFailFile);
    FS := TFileStream.Create(Tmp, fmCreate);
    try
      Http := TFPHTTPClient.Create(nil);
      try
        Http.ConnectTimeout := 15000;
        Http.IOTimeout := 15000;
        Http.AllowRedirect := True;
        Http.MaxRedirects := 5;
        Http.Get(FUrl, FS);
        if (Http.ResponseStatusCode div 100) = 2 then
        begin
          // El valor de la cabecera puede traer espacios delante
          CT := Trim(LowerCase(Http.ResponseHeaders.Values['Content-Type']));
          if (CT = '') or (Pos('image/', CT) = 1) then
            OK := True;
        end;
      finally
        Http.Free;
      end;
    finally
      FS.Free;
    end;
    if OK and RenameFile(Tmp, FFile) then
      { listo: el temporizador lo detectará }
    else
    begin
      DeleteFile(Tmp);
      FS := TFileStream.Create(FFailFile, fmCreate);
      FS.Free;
    end;
  except
    on E: Exception do
    begin
      try
        DeleteFile(Tmp);
        FS := TFileStream.Create(FFailFile, fmCreate);
        FS.Free;
      except
        { ni el marcador: el temporizador lo dará por fallido }
      end;
    end;
  end;
end;

{ TImageFetcher }

constructor TImageFetcher.Create(const ACacheDir: string);
begin
  inherited Create;
  FCacheDir := ACacheDir;
  FStreams := TStringList.Create;
  FStreams.OwnsObjects := True;
  FStreams.Sorted := True;
  FStreams.Duplicates := dupIgnore;
  FInFlight := TStringList.Create;
  FInFlight.Sorted := True;
  FInFlight.Duplicates := dupIgnore;
  FFailed := TStringList.Create;
  FFailed.Sorted := True;
  FFailed.Duplicates := dupIgnore;
  FTimer := TTimer.Create(nil);
  FTimer.Interval := 750;
  FTimer.Enabled := False;
  FTimer.OnTimer := @TimerTick;
end;

destructor TImageFetcher.Destroy;
begin
  // Los hilos en curso son autónomos (FreeOnTerminate) y solo tocan
  // sus propios ficheros; al salir el proceso mueren con él.
  FTimer.Free;
  FFailed.Free;
  FInFlight.Free;
  FStreams.Free;
  inherited;
end;

function TImageFetcher.CacheFileFor(const Url: string): string;
var
  Ext, Path: string;
  k: Integer;
begin
  Path := Url;
  k := Pos('?', Path);
  if k > 0 then
    Path := Copy(Path, 1, k - 1);
  Ext := '';
  for k := Low(IMG_EXTS) to High(IMG_EXTS) do
    if (Length(Path) >= Length(IMG_EXTS[k])) and
      (LowerCase(Copy(Path, Length(Path) - Length(IMG_EXTS[k]) + 1,
        Length(IMG_EXTS[k]))) = IMG_EXTS[k]) then
    begin
      Ext := IMG_EXTS[k];
      Break;
    end;
  Result := IncludeTrailingPathDelimiter(FCacheDir) +
    MD5Print(MD5String(Url)) + Ext;
end;

function TImageFetcher.FailFileFor(const Url: string): string;
begin
  Result := CacheFileFor(Url) + '.failed';
end;

function TImageFetcher.IsPending(const Url: string): Boolean;
begin
  Result := FInFlight.IndexOf(Url) >= 0;
end;

procedure TImageFetcher.StartDownload(const Url: string);
var
  Th: TImageDownloadThread;
begin
  ForceDirectories(FCacheDir);
  FInFlight.Add(Url);
  Th := TImageDownloadThread.Create(Url, CacheFileFor(Url));
  Th.Start;
  FTimer.Enabled := True;
end;

procedure TImageFetcher.TimerTick(Sender: TObject);
var
  i: Integer;
  Url, CF: string;
begin
  for i := FInFlight.Count - 1 downto 0 do
  begin
    Url := FInFlight[i];
    CF := CacheFileFor(Url);
    if FileExists(CF) then
    begin
      FInFlight.Delete(i);
      if Assigned(FOnFetched) then
        FOnFetched(Url, True);
    end
    else if FileExists(FailFileFor(Url)) then
    begin
      DeleteFile(FailFileFor(Url));
      FInFlight.Delete(i);
      FFailed.Add(Url);
      if Assigned(FOnFetched) then
        FOnFetched(Url, False);
    end;
  end;
  if FInFlight.Count = 0 then
    FTimer.Enabled := False;
end;

function TImageFetcher.GetImageStream(const Url: string;
  out Stream: TStream): Boolean;
var
  F: string;
  Idx: Integer;
  MS: TMemoryStream;
  LU: string;
begin
  Result := False;
  Stream := nil;
  LU := LowerCase(Url);
  if (Pos('http://', LU) <> 1) and (Pos('https://', LU) <> 1) then
    Exit; // local, data:, etc.: lo gestiona el visor
  Idx := FStreams.IndexOf(Url);
  if Idx >= 0 then
  begin
    Stream := TStream(FStreams.Objects[Idx]);
    Stream.Position := 0;
    Exit(True);
  end;
  F := CacheFileFor(Url);
  if FileExists(F) then
  begin
    MS := TMemoryStream.Create;
    try
      MS.LoadFromFile(F);
      MS.Position := 0;
    except
      on E: Exception do
      begin
        MS.Free;
        DeleteFile(F);
        Exit(False);
      end;
    end;
    FStreams.AddObject(Url, MS);
    Stream := MS;
    Exit(True);
  end;
  if (FInFlight.IndexOf(Url) >= 0) or (FFailed.IndexOf(Url) >= 0) then
  begin
    Exit(False);
  end;
  try
    StartDownload(Url);
  except
    FFailed.Add(Url);
    Exit(False);
  end;
  Result := False;
end;

end.
