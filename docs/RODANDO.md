# Rodando o app no Windows

Ambiente: Windows 11, Flutter na máquina host, API Go em `http://localhost:8080`. O app só fala com a API pelo valor de `AppConfig.apiUrl` (`API_BASE_URL` + `/v1`).

## 1. Subir a API

O backend vive no repositório irmão `../meu-auto-backend`. Postgres neste computador escuta na porta **5433**, não 5432.

No Git Bash, a partir de `meu-auto-backend`:

```bash
export PATH="$PATH:/c/Program Files/Go/bin"

cp .env.example .env   # só na primeira vez
docker compose up -d   # só o Postgres
set -a && . ./.env && set +a && go run ./cmd/api
```

A API escuta em `:8080` (todas as interfaces). Conferência: `GET http://localhost:8080/healthz` deve responder `{"status":"ok"}`.

O Docker Desktop precisa estar **rodando**, não só instalado. `docker info` é a checagem rápida.

## 2. Emulador Android (`10.0.2.2`)

Dentro do emulador, `localhost` é o próprio emulador. O alias `10.0.2.2` aponta para o loopback do Windows, onde a API está. Por isso `dart_defines/development.json` usa `http://10.0.2.2:8080`.

```bash
flutter emulators --launch Medium_Phone

flutter run --dart-define-from-file=dart_defines/development.json
```

No Cursor, a configuração **Meu Auto (dev)** em `.vscode/launch.json` passa o mesmo arquivo.

Não é preciso abrir o Firewall para o emulador: o tráfego não sai da máquina.

## 3. Aparelho físico na mesma rede

O telefone não alcança `10.0.2.2` nem `localhost` do Windows. Use o IPv4 da máquina na LAN.

1. Descubra o IP:

   ```text
   ipconfig
   ```

   Procure `IPv4` no adaptador Wi-Fi ou Ethernet ativo (ex.: `192.168.0.15`). Telefone e PC precisam estar na mesma rede, sem isolamento de AP.

2. Ajuste `dart_defines/development.json`:

   ```json
   { "API_BASE_URL": "http://192.168.0.15:8080" }
   ```

   Troque pelo IP real. Não commite esse valor se for só da sua rede.

3. Libere HTTP para esse host em `android/app/src/main/res/xml/network_security_config.xml`. Dentro do `domain-config` com `cleartextTrafficPermitted="true"`, acrescente:

   ```xml
   <domain includeSubdomains="false">192.168.0.15</domain>
   ```

4. Abra a porta **8080** no Firewall do Windows (regra de **entrada**, TCP). No PowerShell como administrador:

   ```powershell
   New-NetFirewallRule -DisplayName "Meu Auto API 8080" -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow
   ```

   Pelo interface gráfico: Segurança do Windows → Firewall → Configurações avançadas → Regras de entrada → Nova regra → Porta → TCP 8080 → Permitir.

5. Rode o app apontando para o aparelho:

   ```bash
   flutter run --dart-define-from-file=dart_defines/development.json
   ```

   Se houver mais de um dispositivo: `flutter devices` e `--device-id`.

## 4. Produção

```bash
flutter run --dart-define-from-file=dart_defines/production.json
```

Isso usa a API de produção, `https://meu-auto-backend-production.up.railway.app` — no ar, com os dados reais: uma conta criada daqui é uma conta de verdade. E o app de produção dos celulares não sai desta máquina; sai do Release no GitHub (seção 5.2).

O `dart_defines/production.json` é HTTPS de propósito e não tem par em cleartext. O build de release não carrega nenhuma exceção de HTTP: o `network_security_config.xml` é anexado só pelos manifests de **debug** e **profile** (`android/app/src/{debug,profile}/AndroidManifest.xml`). Com `targetSdk` 28+ e sem config, o Android nega cleartext direto. Se um dia um APK de release precisar falar HTTP, isso é uma decisão, não um ajuste.

No iOS o equivalente é `NSAllowsLocalNetworking` no `Info.plist` — que libera só a rede local, para o Simulator alcançar a API da máquina. **`NSAllowsArbitraryLoads` não está lá e não deve entrar**: é o que a revisão da App Store cobra justificativa.

## 5. Build de release (Android)

```bash
flutter build apk --release --dart-define-from-file=dart_defines/production.json
```

```bash
flutter build appbundle --release --dart-define-from-file=dart_defines/production.json
```

O APK sai em `build/app/outputs/flutter-apk/app-release.apk` e o bundle em `build/app/outputs/bundle/release/app-release.aab`. O `.aab` é o que a Play aceita; o `.apk` serve para instalar direto num aparelho (`adb install -r <caminho>`).

Esquecer o `--dart-define-from-file` faz o build usar o `defaultValue` do `AppConfig`, que é `http://10.0.2.2:8080`. O app compila, instala e não fala com nada. **A flag não é opcional.**

**Estes builds são para testar nesta máquina, não para os celulares.** Sem `android/key.properties` eles saem com a chave de debug, e o Android recusa instalar por cima de um app que veio do Release. O APK dos celulares sai do GitHub — seção 5.2.

### 5.1. Chave de assinatura

Sem `android/key.properties`, o release é assinado com a chave de **debug**: instala e roda no seu aparelho, e a Play recusa. O Gradle avisa em qual dos dois casos você está, no log do build.

Gerar a chave de upload (uma vez, e guarde o `.jks` fora do repositório):

```bash
keytool -genkey -v -keystore meu-auto-upload.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

No Windows, o `keytool` vem com o JDK do Android Studio:

```text
C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe
```

Depois crie `android/key.properties` apontando para ele:

```properties
storePassword=<a senha do keystore>
keyPassword=<a senha da chave>
keyAlias=upload
storeFile=C:/caminho/absoluto/para/meu-auto-upload.jks
```

Use barra normal (`/`) no `storeFile`, inclusive no Windows — barra invertida é escape em arquivo `.properties`.

**`android/key.properties`, `*.jks` e `*.keystore` estão no `.gitignore`.** Confira antes do primeiro commit de release:

```bash
git check-ignore -v android/key.properties
```

Duas coisas que não têm conserto depois: commitar o keystore (qualquer pessoa passa a publicar no seu lugar) e perder o keystore (você nunca mais atualiza o app publicado, só sobe outro com id diferente). Guarde uma cópia num gerenciador de senhas ou cofre da empresa.

### 5.2. Publicar uma versão (Release no GitHub)

O APK que vai para os celulares sai do workflow [`.github/workflows/release-apk.yml`](../.github/workflows/release-apk.yml), não desta máquina. Ele roda quando uma tag `v*` sobe: confere se a tag bate com o `version:` do pubspec, roda analyze e testes (com o `openapi.yaml` do backend ao lado, para o teste de contrato valer), assina com a chave de upload e publica o Release com dois arquivos — `meu-auto-<versão>.apk` e a cópia de nome fixo `meu-auto.apk`, que é o que o "Atualizar o Meu Auto" do Início baixa.

**Uma vez só: os segredos da assinatura.** GitHub → repositório `meu-auto-app` → Settings → Secrets and variables → Actions → New repository secret:

| Segredo | Valor |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | o `.jks` da seção 5.1 em base64 (comando abaixo) |
| `ANDROID_KEYSTORE_PASSWORD` | o `storePassword` |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | o `keyPassword` |

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\caminho\para\meu-auto-upload.jks")) | Set-Clipboard
```

O workflow **falha de propósito**, antes de compilar, se algum faltar: sem eles o Gradle cairia na chave de debug e produziria calado um arquivo que ninguém instala por cima.

**Uma vez só: o link no Railway**, serviço `meu-auto-backend`:

```text
APP_APK_URL = https://github.com/simonscabello/meu-auto-app/releases/latest/download/meu-auto.apk
```

**A cada versão:**

1. Suba o `version:` do `pubspec.yaml`, as duas partes: `1.2.0+3` → `1.3.0+4`. O número depois do `+` é o versionCode do Android e **só pode crescer** — o Android recusa instalar um build menor por cima.
2. Commit, e então `git tag v1.3.0 && git push origin main v1.3.0`.
3. Quando o Release aparecer em [github.com/simonscabello/meu-auto-app/releases](https://github.com/simonscabello/meu-auto-app/releases), defina no Railway `APP_LATEST_VERSION = 1.3.0`. A partir daí, o Início de quem está numa versão anterior mostra "Atualizar o Meu Auto".

Publicar e anunciar são passos separados de propósito: enquanto o passo 3 não acontece, o Release existe para testar e nenhum celular é cobrado.

**O aviso só aparece em APK feito pelo workflow.** É ele que passa `--dart-define=APP_VERSION=...` (`AppConfig.appVersion`); um build desta máquina não sabe a própria versão e nunca é cobrado.

**A troca de chave acontece uma vez.** Um app instalado a partir de um build desta máquina foi assinado com a chave de debug, e o Android não aceita o APK do Release por cima dele: desinstale uma vez, instale o do Release e entre de novo — conta e dados ficam no servidor. Daí em diante, todo Release instala por cima.

**Conferir o que foi publicado.** A chave de upload do Meu Auto (`C:\Users\Acer\keys\meu-auto-upload.jks`, alias `upload` — não é a do Pauta) tem certificado com SHA-256:

```text
639a064d69ced00f0cbf091cfcb2bfcaa8c25877d30eb753af30a9b11ca6f7f2
```

Um Release assinado com outro certificado não instala por cima de nenhum celular. Depois de cada publicação, baixe o `meu-auto.apk` do Release e confira (PowerShell; sem o `JAVA_HOME` o `apksigner` não imprime nada):

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"; & "$env:LOCALAPPDATA\Android\Sdk\build-tools\37.0.0\apksigner.bat" verify --print-certs meu-auto.apk
```

E confirme o anúncio: `https://meu-auto-backend-production.up.railway.app/v1/app-version` tem de trazer a versão nova em `latest_version`.

A primeira versão publicada assim foi a **1.1.0** (versionCode 2), em 26/09/2026.

## 6. Build de release (iOS)

**`flutter build ipa` exige macOS. Esta máquina é Windows e o passo não roda aqui** — não é configuração faltando, é a toolchain da Apple (Xcode, `xcodebuild`, assinatura) que só existe no macOS.

Onde rodar: um Mac, ou um CI com runner macOS (GitHub Actions `macos-latest`, Codemagic, Bitrise).

Pré-requisitos no Mac:

- Xcode com a linha de comando aceita (`sudo xcodebuild -license accept`).
- CocoaPods (`sudo gem install cocoapods`), e `pod install` em `ios/`.
- Conta no Apple Developer Program (US$ 99/ano) — sem ela não há assinatura de distribuição.
- Um App ID registrado para o bundle `br.com.meuauto.meuAuto`, com o perfil de provisionamento correspondente.

O comando:

```bash
flutter build ipa --release --dart-define-from-file=dart_defines/production.json
```

O `.ipa` sai em `build/ios/ipa/`. Subir com `xcrun altool` ou pelo Transporter.

Sobre o bundle id: no Android é `br.com.meuauto.meu_auto`; no iOS é `br.com.meuauto.meuAuto`, sem underline. **Isso é de propósito** — a Apple só aceita alfanumérico, hífen e ponto no `CFBundleIdentifier`, então o underline do Android não tem como ser reproduzido. Não "corrija" um para o outro.

O que dá para fazer no Windows: editar tudo em `ios/` (o esquema `meuauto`, o ATS, os nomes exibidos) e revisar. Só não dá para compilar.

## 7. Deep link de redefinição de senha (sem e-mail)

Em desenvolvimento o backend **não envia** o e-mail: o link aparece no LOG da API (`reset_url`). Copie o token e abra o app com o esquema `meuauto`.

Android (emulador ou aparelho com o app instalado):

```bash
adb shell am start -a android.intent.action.VIEW -d "meuauto://redefinir-senha?token=TESTE"
```

iOS (simulador; exige macOS):

```bash
xcrun simctl openurl booted "meuauto://redefinir-senha?token=TESTE"
```

O token de verdade sai do log depois de `POST /v1/auth/password-reset/request`. `TESTE` só serve para conferir que a tela abre.

Para exercitar o app **já aberto** (warm start), deixe-o em segundo plano e dispare o mesmo comando. Cold start: feche o app de verdade e dispare de novo.

## 8. Gradle: `Failed to find target android-37`

`flutter_secure_storage` 11 exige compileSdk 37. O Android SDK recente instala a pasta `platforms\android-37.0`. Se o Gradle procurar `android-37` e falhar, crie um junction (PowerShell ou cmd):

```bat
mklink /J %LOCALAPPDATA%\Android\sdk\platforms\android-37 %LOCALAPPDATA%\Android\sdk\platforms\android-37.0
```
