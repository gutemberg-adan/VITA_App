# V.I.T.A. Mobile — Flutter/Dart

Aplicativo multiplataforma baseado no V.I.T.A. web v0.0.5, preparado para Android e iOS.

## O que há nesta versão

- Acesso ao aplicativo independente de existir um ESP32 por perto ou de o Bluetooth estar ligado.
- Busca e conexão opcional com dispositivos Bluetooth Low Energy (BLE) na tela **Dispositivo**.
- Solicitação de permissões somente quando o usuário inicia a busca Bluetooth; o login e as demais telas não dependem dessas permissões.
- Estado de conexão refletido no Dashboard.
- Serviço de publicação das últimas medições no widget da tela inicial do telefone.
- Modelos de widget nativo para Android (AppWidget) e iOS (WidgetKit), em `platform_setup/`.
- Painel, histórico, gráficos, relatórios PDF, alertas, configurações, ajuda, calendário e SOS demonstrativo.

## Limites técnicos importantes

A descoberta BLE e a conexão GATT inicial estão implementadas. **A leitura dos sensores ainda depende de o firmware ESP32 definir e documentar o protocolo GATT**: UUID do serviço, UUIDs das características, formato dos dados, unidades, frequência de notificação e eventual autenticação. Não foram inventados UUIDs nem um formato de pacote. Até essa definição, os valores no Dashboard/widget continuam identificados como dados demonstrativos/últimos registros locais; a conexão BLE, sozinha, não significa que os sinais vitais reais estejam chegando.

O widget exibe os últimos valores gravados pelo aplicativo. Widgets de iOS/Android são atualizados pelo sistema operacional e não têm atualização contínua garantida; no iOS, o WidgetKit controla a frequência de atualização. O widget não substitui o aplicativo nem é um monitor médico em tempo real.

## Requisitos

- Flutter estável com Dart 3.4 ou superior.
- Android Studio/Android SDK para Android.
- macOS com Xcode para compilar e assinar iOS.

## Preparar o projeto

Na pasta `vita_flutter`:

```bash
flutter create . --platforms=android,ios
flutter pub get
```

### Android — BLE e widget

1. Mescle as permissões e o `<receiver>` de `platform_setup/android/AndroidManifest.snippet.xml` no `android/app/src/main/AndroidManifest.xml` (permissões fora de `<application>`; receiver dentro de `<application>`).
2. Copie `platform_setup/android/kotlin/com/vita/vita_app/VitaHomeWidgetProvider.kt` para o diretório Kotlin correspondente ao package da aplicação. Se o package gerado não for `com.vita.vita_app`, ajuste a primeira linha do arquivo e os imports de `R`.
3. Copie `platform_setup/android/res/layout/vita_home_widget.xml` para `android/app/src/main/res/layout/`.
4. Copie `platform_setup/android/res/xml/vita_home_widget_info.xml` para `android/app/src/main/res/xml/` (crie `xml/` se necessário).
5. Garanta `minSdk` compatível com os plugins BLE (21 ou superior).
6. Compile e instale o app. Para adicionar o widget, pressione a tela inicial do Android, abra Widgets e escolha **V.I.T.A. · Medições**.

### iOS — BLE e widget

1. Adicione as chaves de Bluetooth de `platform_setup/ios/InfoPlist.snippet.xml` ao `ios/Runner/Info.plist`.
2. No Xcode, crie uma extensão **Widget Extension** chamada `VitaHomeWidget`.
3. Adicione `platform_setup/ios/VitaHomeWidget.swift` ao target da extensão Widget Extension (não apenas ao target Runner).
4. Ative App Groups nos targets Runner e Widget Extension e marque `group.com.vita.monitoramento`, que é o identificador usado em `lib/services/vita_home_widget_service.dart` e no Swift.
5. Compile no macOS com Xcode. O usuário adiciona o widget pelo editor da tela inicial do iPhone.

## Executar

```bash
flutter run
```

Android:

```bash
flutter build apk --release
# ou
flutter build appbundle --release
```

iOS (macOS + Xcode):

```bash
cd ios && pod install && cd ..
flutter build ios --release
```

## Protocolo ESP32 que falta definir

Para ativar as medições reais, o firmware deverá anunciar um serviço BLE GATT estável e expor características para, no mínimo:

- Temperatura corporal;
- Frequência cardíaca;
- SpO₂;
- Bateria do dispositivo (opcional, mas recomendada);
- Estado/SOS, se fizer parte do protocolo.

Definir também se os dados serão enviados por notificações (`notify`) ou leitura (`read`), codificação (por exemplo JSON UTF-8 ou bytes estruturados), precisão, timestamp, identificação do dispositivo e comportamento em desconexões. Com essa especificação, a camada BLE poderá assinar as características, validar pacotes e alimentar a mesma fonte de dados usada por Dashboard, Histórico, Gráficos, Alertas, Relatórios e widget.

## Segurança e uso

- Não use dados demonstrativos para decisões clínicas.
- A tela de login permanece demonstrativa e não valida credenciais em servidor.
- O SOS ainda não envia alertas reais.
- A comunicação BLE deverá ser protegida conforme o modelo de ameaça e as capacidades do ESP32; não transmitir dados pessoais ou clínicos sem autenticação/criptografia apropriadas.
- O aplicativo não substitui avaliação profissional.
