import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/produto_estoque.dart';

class CsvService {
  static const String _cabecalho = 'Produto,Quantidade,DataHora';

  // ── Cabeçalho esperado (flexível) ─────────────────────────────────────────
  static bool _isCabecalho(List<dynamic> row) {
    if (row.isEmpty) return false;
    final first = row[0].toString().toLowerCase().trim();
    return first == 'produto' || first == 'gtin' || first == 'ean';
  }

  // ── Selecionar arquivo existente via File Picker ──────────────────────────
  Future<File?> selecionarArquivo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final path = result.files.single.path;
    if (path == null) return null;
    return File(path);
  }

  // ── Ler produtos de um arquivo CSV ────────────────────────────────────────
  Future<List<ProdutoEstoque>> lerArquivo(File arquivo) async {
    try {
      final conteudo = await arquivo.readAsString();
      final linhas = const CsvToListConverter(eol: '\n').convert(conteudo);
      final produtos = <ProdutoEstoque>[];

      for (final linha in linhas) {
        if (linha.isEmpty) continue;
        if (_isCabecalho(linha)) continue;
        try {
          produtos.add(ProdutoEstoque.fromCsv(linha));
        } catch (_) {
          // ignora linhas malformadas
        }
      }
      return produtos;
    } catch (e) {
      throw Exception('Erro ao ler arquivo: $e');
    }
  }

  // ── Salvar lista de produtos em um arquivo CSV ────────────────────────────
  Future<File> salvarArquivo(
    List<ProdutoEstoque> produtos, {
    File? arquivoOrigem,
  }) async {
    final linhas = <List<dynamic>>[];

    // cabeçalho
    linhas.add(['Produto', 'Quantidade', 'DataHora']);

    // dados
    for (final p in produtos) {
      linhas.add(p.toCsvRow());
    }

    final csv = const ListToCsvConverter().convert(linhas);

    File destino;
    if (arquivoOrigem != null) {
      destino = arquivoOrigem;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final nome = 'estoque_${DateTime.now().millisecondsSinceEpoch}.csv';
      destino = File('${dir.path}/$nome');
    }

    await destino.writeAsString(csv);
    return destino;
  }

  // ── Criar arquivo novo em branco no diretório de documentos ──────────────
  Future<File> criarNovoArquivo(String nomeArquivo) async {
    final dir = await getApplicationDocumentsDirectory();
    final nome = nomeArquivo.endsWith('.csv') ? nomeArquivo : '$nomeArquivo.csv';
    final arquivo = File('${dir.path}/$nome');
    await arquivo.writeAsString('$_cabecalho\n');
    return arquivo;
  }

  // ── Exportar / Compartilhar via Share Sheet do Android ───────────────────
  Future<void> compartilharArquivo(File arquivo) async {
    await Share.shareXFiles(
      [XFile(arquivo.path)],
      subject: 'Contagem de Estoque',
      text: 'Arquivo CSV de contagem de estoque',
    );
  }

  // ── Listar arquivos salvos no diretório interno do app ───────────────────
  Future<List<File>> listarArquivosSalvos() async {
    final dir = await getApplicationDocumentsDirectory();
    final arquivos = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.csv') || f.path.endsWith('.txt'))
        .toList();
    arquivos.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return arquivos;
  }
}
