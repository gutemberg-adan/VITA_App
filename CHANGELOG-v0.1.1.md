# V.I.T.A. Flutter v0.1.1 — BLE + Home Widget

- Login e navegação continuam independentes do estado do Bluetooth e da existência de um ESP32.
- Adicionada busca BLE sob demanda, solicitação de permissões no momento da busca e conexão/desconexão.
- Adicionada descoberta dos serviços GATT após conectar.
- Dashboard agora mostra o estado real da conexão BLE (online/offline).
- Adicionado serviço de sincronização das últimas medições para o widget de tela inicial.
- Incluídos modelos nativos de widget para Android e iOS e instruções de integração dos targets.
- Valores permanecem demonstrativos até o firmware ESP32 definir UUIDs e formato de dados GATT.
