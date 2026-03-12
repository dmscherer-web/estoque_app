# 📦 Contagem de Estoque — App Flutter

App Android para contagem de estoque usando leitura de código de barras (GTIN/EAN) e exportação em CSV.

---

## ✅ Funcionalidades

- 📂 Abrir um arquivo CSV existente do dispositivo
- ➕ Criar novo arquivo CSV do zero
- 📷 Bipar código de barras GTIN/EAN com a câmera
- 🔢 Digitar a quantidade de cada produto
- 💾 Salvo automaticamente após cada bipagem
- ✏️ Editar ou remover produtos da lista
- 🔍 Buscar produtos por GTIN
- 📤 Compartilhar/exportar o CSV via WhatsApp, e-mail, Drive etc.
- ⌨️ Digitar GTIN manualmente (sem câmera)

---

## 📁 Estrutura do Projeto

```
estoque_app/
├── lib/
│   ├── main.dart                    # Ponto de entrada
│   ├── models/
│   │   └── produto_estoque.dart     # Modelo de dados
│   ├── services/
│   │   └── csv_service.dart         # Leitura e escrita de CSV
│   └── screens/
│       ├── home_screen.dart         # Tela principal
│       ├── scanner_screen.dart      # Scanner de código de barras
│       └── lista_screen.dart        # Visualizar/editar lista
├── android/
│   └── app/src/main/
│       ├── AndroidManifest.xml      # Permissões e configurações
│       └── res/xml/file_paths.xml   # Caminhos para FileProvider
└── pubspec.yaml                     # Dependências do projeto
```

---

## 🚀 Como rodar

### Pré-requisitos

1. [Flutter SDK](https://flutter.dev/docs/get-started/install) — versão 3.x ou superior
2. Android Studio ou VS Code com extensão Flutter
3. Dispositivo Android físico (recomendado) ou emulador com câmera virtual

### Passo a passo

```bash
# 1. Clone ou copie a pasta estoque_app

# 2. Instale as dependências
cd estoque_app
flutter pub get

# 3. Conecte um dispositivo Android (USB debugging ativado)
flutter devices

# 4. Execute o app
flutter run

# 5. Para gerar o APK de instalação
flutter build apk --release
# APK gerado em: build/app/outputs/flutter-apk/app-release.apk
```

---

## 📄 Formato do CSV

O arquivo CSV segue este formato:

```
Produto,Quantidade,DataHora
7891234567890,10,2024-10-15T14:32:00.000
7890000012345,5,2024-10-15T14:35:00.000
```

> O app aceita arquivos com apenas duas colunas (Produto, Quantidade) ou arquivos gerados pelo próprio app com três colunas (incluindo DataHora).

---

## 📦 Dependências usadas

| Pacote | Versão | Função |
|---|---|---|
| `mobile_scanner` | ^5.2.3 | Leitura de código de barras pela câmera |
| `file_picker` | ^8.1.2 | Seleção de arquivos do dispositivo |
| `path_provider` | ^2.1.3 | Acesso ao sistema de arquivos |
| `csv` | ^6.0.0 | Leitura e escrita de arquivos CSV |
| `permission_handler` | ^11.3.1 | Solicitação de permissões Android |
| `share_plus` | ^10.0.0 | Compartilhamento de arquivos |
| `intl` | ^0.19.0 | Formatação de datas |

---

## 📱 Compatibilidade

- Android 6.0 (API 23) ou superior
- Requer câmera traseira com autofoco para melhor leitura de códigos de barras

---

## 💡 Dicas de uso

1. **Colocar o arquivo CSV no celular**: Pode ser enviado por WhatsApp, Google Drive, e-mail, ou copiado via USB. O app usa o seletor nativo de arquivos do Android para encontrá-lo.
2. **Auto-save**: O app salva automaticamente após cada bipagem. Não é necessário salvar manualmente.
3. **Produto já existente**: Se o mesmo GTIN for bipado duas vezes, o app pergunta se deseja somar ou substituir a quantidade.
4. **Exportar**: Use o botão de compartilhar (📤) na tela principal para enviar o CSV por WhatsApp, e-mail, Google Drive, etc.
