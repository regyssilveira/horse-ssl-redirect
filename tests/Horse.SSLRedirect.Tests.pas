unit Horse.SSLRedirect.Tests;

interface

uses
  DUnitX.TestFramework,
  Horse,
  Horse.SSLRedirect,
  System.Net.HttpClient,
  System.Net.URLClient,
  System.SysUtils,
  System.Classes,
  System.Threading;

type
  [TestFixture]
  TTestHorseSSLRedirect = class
  private
    const TEST_PORT = 9091;
  public
    [SetupFixture]
    procedure SetupFixture;
    [TearDownFixture]
    procedure TearDownFixture;

    [Test]
    procedure TestLocalhostAllowedByDefault;
    [Test]
    procedure TestExternalHostRedirectedByDefault;
    [Test]
    procedure TestProxyProtoSecureAllowed;
    [Test]
    procedure TestProxySslSecureAllowed;
    [Test]
    procedure TestProxyFrontEndSecureAllowed;
    [Test]
    procedure TestLocalhostRedirectedWhenConfigured;
    [Test]
    procedure TestCustomPortInRedirect;
    [Test]
    procedure TestCustomRedirectStatus;
  end;

implementation

uses
  Horse.Commons;

{ TTestHorseSSLRedirect }

procedure TTestHorseSSLRedirect.SetupFixture;
var
  LConfigRedirectLocal: THorseSSLRedirectConfig;
  LConfigCustomPort: THorseSSLRedirectConfig;
  LConfigCustomStatus: THorseSSLRedirectConfig;
begin
  // 1. Configuração padrão (RedirectLocalhost = False, TrustProxy = True, SSLPort = 443, Status = 301)
  THorse.Use('/default', SSLRedirect());
  THorse.Get('/default',
    procedure(Req: THorseRequest; Res: THorseResponse)
    begin
      Res.Send('OK-DEFAULT');
    end);

  // 2. Configuração com RedirectLocalhost = True
  LConfigRedirectLocal := THorseSSLRedirectConfig.Default;
  LConfigRedirectLocal.RedirectLocalhost := True;
  THorse.Use('/redirect-local', SSLRedirect(LConfigRedirectLocal));
  THorse.Get('/redirect-local',
    procedure(Req: THorseRequest; Res: THorseResponse)
    begin
      Res.Send('OK-REDIRECT-LOCAL');
    end);

  // 3. Configuração com Porta Customizada
  LConfigCustomPort := THorseSSLRedirectConfig.Default;
  LConfigCustomPort.RedirectLocalhost := True;
  LConfigCustomPort.SSLPort := 8443;
  THorse.Use('/custom-port', SSLRedirect(LConfigCustomPort));
  THorse.Get('/custom-port',
    procedure(Req: THorseRequest; Res: THorseResponse)
    begin
      Res.Send('OK-CUSTOM-PORT');
    end);

  // 4. Configuração com Status Customizado (302)
  LConfigCustomStatus := THorseSSLRedirectConfig.Default;
  LConfigCustomStatus.RedirectLocalhost := True;
  LConfigCustomStatus.RedirectStatus := 302;
  THorse.Use('/custom-status', SSLRedirect(LConfigCustomStatus));
  THorse.Get('/custom-status',
    procedure(Req: THorseRequest; Res: THorseResponse)
    begin
      Res.Send('OK-CUSTOM-STATUS');
    end);

  TThread.CreateAnonymousThread(
    procedure
    begin
      THorse.Listen(TEST_PORT);
    end).Start;

  Sleep(1000); // Aguarda o servidor inicializar
end;

procedure TTestHorseSSLRedirect.TearDownFixture;
begin
  THorse.StopListen;
  Sleep(500);
end;

procedure TTestHorseSSLRedirect.TestLocalhostAllowedByDefault;
var
  LClient: THTTPClient;
  LResponse: IHTTPResponse;
begin
  LClient := THTTPClient.Create;
  try
    LResponse := LClient.Get(Format('http://localhost:%d/default', [TEST_PORT]));
    Assert.AreEqual(200, LResponse.StatusCode);
    Assert.AreEqual('OK-DEFAULT', LResponse.ContentAsString);
  finally
    LClient.Free;
  end;
end;

procedure TTestHorseSSLRedirect.TestExternalHostRedirectedByDefault;
var
  LClient: THTTPClient;
  LResponse: IHTTPResponse;
  LHeaders: TNetHeaders;
begin
  LClient := THTTPClient.Create;
  try
    LClient.HandleRedirects := False;
    
    SetLength(LHeaders, 1);
    LHeaders[0].Name := 'Host';
    LHeaders[0].Value := 'minhaapi.com';

    LResponse := LClient.Get(Format('http://localhost:%d/default', [TEST_PORT]), nil, LHeaders);
    
    Assert.AreEqual(301, LResponse.StatusCode);
    Assert.IsTrue(LResponse.ContainsHeader('Location'), 'A resposta deve conter o header Location');
    Assert.AreEqual('https://minhaapi.com/default', LResponse.HeaderValue['Location']);
  finally
    LClient.Free;
  end;
end;

procedure TTestHorseSSLRedirect.TestProxyProtoSecureAllowed;
var
  LClient: THTTPClient;
  LResponse: IHTTPResponse;
  LHeaders: TNetHeaders;
begin
  LClient := THTTPClient.Create;
  try
    SetLength(LHeaders, 2);
    LHeaders[0].Name := 'Host';
    LHeaders[0].Value := 'minhaapi.com';
    LHeaders[1].Name := 'X-Forwarded-Proto';
    LHeaders[1].Value := 'https';

    LResponse := LClient.Get(Format('http://localhost:%d/default', [TEST_PORT]), nil, LHeaders);
    
    Assert.AreEqual(200, LResponse.StatusCode);
    Assert.AreEqual('OK-DEFAULT', LResponse.ContentAsString);
  finally
    LClient.Free;
  end;
end;

procedure TTestHorseSSLRedirect.TestProxySslSecureAllowed;
var
  LClient: THTTPClient;
  LResponse: IHTTPResponse;
  LHeaders: TNetHeaders;
begin
  LClient := THTTPClient.Create;
  try
    SetLength(LHeaders, 2);
    LHeaders[0].Name := 'Host';
    LHeaders[0].Value := 'minhaapi.com';
    LHeaders[1].Name := 'X-Forwarded-Ssl';
    LHeaders[1].Value := 'on';

    LResponse := LClient.Get(Format('http://localhost:%d/default', [TEST_PORT]), nil, LHeaders);
    
    Assert.AreEqual(200, LResponse.StatusCode);
    Assert.AreEqual('OK-DEFAULT', LResponse.ContentAsString);
  finally
    LClient.Free;
  end;
end;

procedure TTestHorseSSLRedirect.TestProxyFrontEndSecureAllowed;
var
  LClient: THTTPClient;
  LResponse: IHTTPResponse;
  LHeaders: TNetHeaders;
begin
  LClient := THTTPClient.Create;
  try
    SetLength(LHeaders, 2);
    LHeaders[0].Name := 'Host';
    LHeaders[0].Value := 'minhaapi.com';
    LHeaders[1].Name := 'Front-End-Https';
    LHeaders[1].Value := 'on';

    LResponse := LClient.Get(Format('http://localhost:%d/default', [TEST_PORT]), nil, LHeaders);
    
    Assert.AreEqual(200, LResponse.StatusCode);
    Assert.AreEqual('OK-DEFAULT', LResponse.ContentAsString);
  finally
    LClient.Free;
  end;
end;

procedure TTestHorseSSLRedirect.TestLocalhostRedirectedWhenConfigured;
var
  LClient: THTTPClient;
  LResponse: IHTTPResponse;
begin
  LClient := THTTPClient.Create;
  try
    LClient.HandleRedirects := False;
    LResponse := LClient.Get(Format('http://localhost:%d/redirect-local', [TEST_PORT]));
    
    Assert.AreEqual(301, LResponse.StatusCode);
    Assert.IsTrue(LResponse.ContainsHeader('Location'));
    Assert.AreEqual('https://localhost/redirect-local', LResponse.HeaderValue['Location']);
  finally
    LClient.Free;
  end;
end;

procedure TTestHorseSSLRedirect.TestCustomPortInRedirect;
var
  LClient: THTTPClient;
  LResponse: IHTTPResponse;
begin
  LClient := THTTPClient.Create;
  try
    LClient.HandleRedirects := False;
    LResponse := LClient.Get(Format('http://localhost:%d/custom-port', [TEST_PORT]));
    
    Assert.AreEqual(301, LResponse.StatusCode);
    Assert.IsTrue(LResponse.ContainsHeader('Location'));
    Assert.AreEqual('https://localhost:8443/custom-port', LResponse.HeaderValue['Location']);
  finally
    LClient.Free;
  end;
end;

procedure TTestHorseSSLRedirect.TestCustomRedirectStatus;
var
  LClient: THTTPClient;
  LResponse: IHTTPResponse;
begin
  LClient := THTTPClient.Create;
  try
    LClient.HandleRedirects := False;
    LResponse := LClient.Get(Format('http://localhost:%d/custom-status', [TEST_PORT]));
    
    Assert.AreEqual(302, LResponse.StatusCode);
    Assert.IsTrue(LResponse.ContainsHeader('Location'));
    Assert.AreEqual('https://localhost/custom-status', LResponse.HeaderValue['Location']);
  finally
    LClient.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestHorseSSLRedirect);

end.
