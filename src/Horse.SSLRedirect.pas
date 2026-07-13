unit Horse.SSLRedirect;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}{$H+}
{$ENDIF}

interface

uses
  {$IF DEFINED(FPC)}
    SysUtils,
  {$ELSE}
    System.SysUtils,
  {$ENDIF}
  Horse;

type
  THorseSSLRedirectConfig = record
  private
    FTrustProxy: Boolean;
    FRedirectLocalhost: Boolean;
    FSSLPort: Integer;
    FRedirectStatus: Integer;
  public
    property TrustProxy: Boolean read FTrustProxy write FTrustProxy;
    property RedirectLocalhost: Boolean read FRedirectLocalhost write FRedirectLocalhost;
    property SSLPort: Integer read FSSLPort write FSSLPort;
    property RedirectStatus: Integer read FRedirectStatus write FRedirectStatus;
    class function Default: THorseSSLRedirectConfig; static;
  end;

function SSLRedirect: THorseCallback; overload;
function SSLRedirect(const AConfig: THorseSSLRedirectConfig): THorseCallback; overload;

implementation

uses
  {$IF DEFINED(FPC)}
    httpdefs, StrUtils,
  {$ELSE}
    Web.HTTPApp, System.StrUtils,
  {$ENDIF}
  Horse.Commons;

{ THorseSSLRedirectConfig }

class function THorseSSLRedirectConfig.Default: THorseSSLRedirectConfig;
begin
  Result.FTrustProxy := True;
  Result.FRedirectLocalhost := False;
  Result.FSSLPort := 443;
  Result.FRedirectStatus := 301; // THTTPStatus.MovedPermanently = 301
end;

function IsLocalhost(const AHost: string): Boolean;
var
  LHostClean: string;
  LColonPos: Integer;
begin
  LHostClean := Trim(AHost);
  LColonPos := Pos(':', LHostClean);
  if LColonPos > 0 then
    LHostClean := Copy(LHostClean, 1, LColonPos - 1);

  Result := (CompareText(LHostClean, 'localhost') = 0) or
            (CompareText(LHostClean, '127.0.0.1') = 0) or
            (CompareText(LHostClean, '::1') = 0);
end;

function IsHTTPS(AReq: THorseRequest; ATrustProxy: Boolean; ASSLPort: Integer): Boolean;
var
  LProto: string;
begin
  if ATrustProxy then
  begin
    LProto := AReq.Headers['X-Forwarded-Proto'];
    if CompareText(LProto, 'https') = 0 then
      Exit(True);

    LProto := AReq.Headers['X-Forwarded-Ssl'];
    if CompareText(LProto, 'on') = 0 then
      Exit(True);

    LProto := AReq.Headers['Front-End-Https'];
    if CompareText(LProto, 'on') = 0 then
      Exit(True);
  end;

  {$IF DEFINED(FPC)}
  Result := (AReq.RawWebRequest.ServerPort = ASSLPort) or
            ((ASSLPort = 443) and (AReq.RawWebRequest.ServerPort = 443)) or
            (Pos('https://', LowerCase(AReq.RawWebRequest.URL)) = 1);
  {$ELSE}
  Result := (Pos('https://', LowerCase(AReq.RawWebRequest.URL)) = 1);
  {$ENDIF}
end;

{$IF DEFINED(FPC)}
var
  FConfig: THorseSSLRedirectConfig;

procedure Middleware(Req: THorseRequest; Res: THorseResponse; Next: TNextProc);
var
  LHost, LURL, LQuery: string;
  LIsSecure: Boolean;
begin
  LHost := Req.Headers['Host'];
  if LHost = '' then
    LHost := Req.RawWebRequest.Host;

  LIsSecure := IsHTTPS(Req, FConfig.TrustProxy, FConfig.SSLPort);

  if not LIsSecure then
  begin
    if (not FConfig.RedirectLocalhost) and IsLocalhost(LHost) then
    begin
      Next();
      Exit;
    end;

    LURL := 'https://';
    if Pos(':', LHost) > 0 then
      LHost := Copy(LHost, 1, Pos(':', LHost) - 1);

    LURL := LURL + LHost;

    if (FConfig.SSLPort <> 443) and (FConfig.SSLPort <> 0) then
      LURL := LURL + ':' + IntToStr(FConfig.SSLPort);

    LURL := LURL + Req.RawWebRequest.PathInfo;

    LQuery := Req.RawWebRequest.Query;
    if LQuery <> '' then
      LURL := LURL + '?' + LQuery;

    Res.Status(THTTPStatus(FConfig.RedirectStatus));
    Res.RawWebResponse.SetCustomHeader('Location', LURL);
    Res.Send('');
    raise EHorseCallbackInterrupted.Create();
  end
  else
    Next();
end;
{$ENDIF}

function SSLRedirect(const AConfig: THorseSSLRedirectConfig): THorseCallback;
{$IFNDEF FPC}
var
  LConfig: THorseSSLRedirectConfig;
{$ENDIF}
begin
  {$IF DEFINED(FPC)}
  FConfig := AConfig;
  Result := Middleware;
  {$ELSE}
  LConfig := AConfig;
  Result := procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
  var
    LHost, LURL, LQuery: string;
    LIsSecure: Boolean;
  begin
    LHost := Req.Headers['Host'];
    if LHost = '' then
      LHost := Req.RawWebRequest.Host;

    LIsSecure := IsHTTPS(Req, LConfig.TrustProxy, LConfig.SSLPort);

    if not LIsSecure then
    begin
      if (not LConfig.RedirectLocalhost) and IsLocalhost(LHost) then
      begin
        Next();
        Exit;
      end;

      LURL := 'https://';
      if Pos(':', LHost) > 0 then
        LHost := Copy(LHost, 1, Pos(':', LHost) - 1);

      LURL := LURL + LHost;

      if (LConfig.SSLPort <> 443) and (LConfig.SSLPort <> 0) then
        LURL := LURL + ':' + IntToStr(LConfig.SSLPort);

      LURL := LURL + Req.RawWebRequest.PathInfo;

      LQuery := Req.RawWebRequest.Query;
      if LQuery <> '' then
        LURL := LURL + '?' + LQuery;

      Res.Status(THTTPStatus(LConfig.RedirectStatus));
      Res.RawWebResponse.SetCustomHeader('Location', LURL);
      Res.Send('');
      raise EHorseCallbackInterrupted.Create();
    end
    else
      Next();
  end;
  {$ENDIF}
end;

function SSLRedirect: THorseCallback;
begin
  Result := SSLRedirect(THorseSSLRedirectConfig.Default);
end;

end.
