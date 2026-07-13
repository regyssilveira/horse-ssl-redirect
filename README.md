# horse-ssl-redirect

Middleware para redirecionamento automático de requisições HTTP inseguras para HTTPS no framework **Horse**.

---

## 💡 Por que utilizar o redirecionamento SSL?

O redirecionamento de conexões HTTP para HTTPS é um componente essencial de segurança para aplicações e APIs modernas pelas seguintes razões:

1. **Criptografia e Proteção de Dados:** Garante que dados confidenciais (credenciais, tokens, informações pessoais sob LGPD) sejam criptografados por TLS/SSL durante o trânsito, mitigando ataques de interceptação (*Man-in-the-Middle*).
2. **Independência de Infraestrutura:** Garante segurança nativa na aplicação. Se o servidor for exposto diretamente à rede, ou se o proxy reverso (IIS, Nginx, ALB AWS) falhar na configuração de redirecionamento, a aplicação Horse continuará protegendo o tráfego.
3. **Conformidade de Segurança (Compliance):** Essencial para atender a requisitos regulatórios como PCI-DSS, ISO 27001 e conformidade da LGPD/GDPR.
4. **Prevenção de Sequestro de Sessão (Cookie Hijacking):** Garante que cookies de autenticação e cabeçalhos de autorização não vazem em requisições de texto plano.
5. **SEO (Search Engine Optimization):** Mecanismos de busca priorizam URLs seguras. O redirecionamento com código **301 (Moved Permanently)** consolida a reputação das rotas.

---

## ⚡ Instalação

Adicione o middleware ao seu projeto usando o [Boss](https://github.com/Hashload/boss):

```bash
boss install github.com/regyssilveira/horse-ssl-redirect
```

---

## 🚀 Como Utilizar

### Exemplo Básico

Por padrão, o middleware não redirecionará conexões originadas de `localhost` ou `127.0.0.1` para não interromper os testes de desenvolvimento local.

```pascal
program Sample;

{$APPTYPE CONSOLE}

uses
  Horse,
  Horse.SSLRedirect;

begin
  THorse.Use(SSLRedirect);

  THorse.Get('/ping',
    procedure(Req: THorseRequest; Res: THorseResponse)
    begin
      Res.Send('pong');
    end);

  THorse.Listen(9000);
end.
```

### Configurações Avançadas

Você pode customizar o comportamento do middleware instanciando e parametrizando `THorseSSLRedirectConfig`.

```pascal
program SampleAdvanced;

{$APPTYPE CONSOLE}

uses
  Horse,
  Horse.SSLRedirect,
  Horse.Commons;

var
  LConfig: THorseSSLRedirectConfig;
begin
  // Configuração customizada
  LConfig.TrustProxy := True;           // Confia em cabeçalhos de proxy (ex: X-Forwarded-Proto)
  LConfig.RedirectLocalhost := True;    // Redireciona mesmo em localhost (útil para testar SSL local)
  LConfig.SSLPort := 8443;              // Porta SSL utilizada no redirecionamento (se diferente de 443)
  LConfig.RedirectStatus := 302;        // Usa redirecionamento temporário (302 Found) ao invés de 301

  THorse.Use(SSLRedirect(LConfig));

  THorse.Get('/ping',
    procedure(Req: THorseRequest; Res: THorseResponse)
    begin
      Res.Send('pong');
    end);

  THorse.Listen(9000);
end.
```

---

## 🛠️ Opções de Configuração

O registro `THorseSSLRedirectConfig` possui as seguintes opções:

* **`TrustProxy`** (Boolean - Padrão: `True`): Quando ativado, verifica os cabeçalhos `X-Forwarded-Proto`, `X-Forwarded-Ssl` e `Front-End-Https` enviados por balanceadores de carga ou proxies reversos para verificar se a requisição original já era HTTPS.
* **`RedirectLocalhost`** (Boolean - Padrão: `False`): Se `False`, requisições com hosts `localhost`, `127.0.0.1` ou `::1` não serão redirecionadas, facilitando o desenvolvimento sem HTTPS local.
* **`SSLPort`** (Integer - Padrão: `443`): A porta para a qual a requisição deve ser redirecionada. Se diferente de `443`, a porta será adicionada na URL de redirecionamento.
* **`RedirectStatus`** (Integer - Padrão: `301` / `MovedPermanently`): O código de status HTTP retornado na resposta de redirecionamento.

---

## 📄 Licença

Este projeto é licenciado sob a Licença MIT - veja o arquivo [LICENSE](LICENSE) para detalhes.
