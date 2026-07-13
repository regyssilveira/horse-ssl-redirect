---
name: horse-ssl-redirect
description: Guidelines and workflows for developing and maintaining the horse-ssl-redirect middleware within the Horse framework.
---

# Uso e Desenvolvimento do Horse SSL Redirect

Diretrizes e exemplos práticos para guiar modelos de linguagem (LLMs) na utilização correta deste middleware.

## 🟢 Como Registrar o Middleware

O middleware `horse-ssl-redirect` deve ser registrado no pipeline principal do Horse utilizando a função `SSLRedirect`. Ele aceita uma configuração opcional `THorseSSLRedirectConfig`.

### Exemplo Básico:
```pascal
uses
  Horse,
  Horse.SSLRedirect;

begin
  THorse.Use(SSLRedirect);
  // ...
end.
```

### Exemplo com Configuração Customizada:
```pascal
uses
  Horse,
  Horse.SSLRedirect;

var
  LConfig: THorseSSLRedirectConfig;
begin
  LConfig.TrustProxy := True;
  LConfig.RedirectLocalhost := False;
  LConfig.SSLPort := 443;
  LConfig.RedirectStatus := 301;

  THorse.Use(SSLRedirect(LConfig));
  // ...
end.
```

## 🟢 Comportamento e Tratamento de Exceções

Ao interceptar uma requisição HTTP insegura, o middleware realiza as seguintes ações:
1. Reconstrói a URL do request substituindo o esquema para `https://` e concatenando o `Host`, `PathInfo` e `Query` (se houver).
2. Se a porta configurada em `SSLPort` for diferente de `443` e `0`, ela será explicitamente incluída na URL de redirecionamento.
3. Preenche a resposta do Horse (`Res`) com o código de status configurado (padrão `301 Moved Permanently`) e adiciona o header `Location` contendo a URL segura recalculada.
4. Finaliza a requisição lançando `EHorseCallbackInterrupted.Create()` para interromper a execução do pipeline de maneira limpa.

### Tratamento de Proxies e Localhost
* **`TrustProxy`**: Habilita a inspeção de cabeçalhos comuns como `X-Forwarded-Proto` (https), `X-Forwarded-Ssl` (on) e `Front-End-Https` (on).
* **`RedirectLocalhost`**: Se for `False` (padrão), ignora requisições vindas de hosts locais (como `localhost`, `127.0.0.1` ou `::1`) para evitar loops em ambiente de desenvolvimento local.
