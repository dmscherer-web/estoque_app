import 'dart:io';
import 'package:flutter/material.dart';
import '../services/csv_service.dart';
import '../models/produto_estoque.dart';
import 'scanner_screen.dart';
import 'lista_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CsvService _csvService = CsvService();
  File? _arquivoAtual;
  List<ProdutoEstoque> _produtos = [];
  bool _carregando = false;
  String? _mensagem;

  // ── Selecionar arquivo CSV existente ──────────────────────────────────────
  Future<void> _selecionarArquivo() async {
    setState(() { _carregando = true; _mensagem = null; });
    try {
      final arquivo = await _csvService.selecionarArquivo();
      if (arquivo == null) {
        setState(() { _carregando = false; });
        return;
      }
      final produtos = await _csvService.lerArquivo(arquivo);
      setState(() {
        _arquivoAtual = arquivo;
        _produtos = produtos;
        _carregando = false;
        _mensagem = '${produtos.length} produto(s) carregado(s)';
      });
    } catch (e) {
      setState(() {
        _carregando = false;
        _mensagem = 'Erro: $e';
      });
    }
  }

  // ── Criar novo arquivo CSV ────────────────────────────────────────────────
  Future<void> _criarNovoArquivo() async {
    final controller = TextEditingController(
      text: 'estoque_${DateTime.now().day.toString().padLeft(2, '0')}'
            '_${DateTime.now().month.toString().padLeft(2, '0')}'
            '_${DateTime.now().year}',
    );
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Novo arquivo'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nome do arquivo',
            suffixText: '.csv',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Criar')),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() { _carregando = true; });
    try {
      final arquivo = await _csvService.criarNovoArquivo(controller.text.trim());
      setState(() {
        _arquivoAtual = arquivo;
        _produtos = [];
        _carregando = false;
        _mensagem = 'Arquivo criado: ${arquivo.path.split('/').last}';
      });
    } catch (e) {
      setState(() { _carregando = false; _mensagem = 'Erro: $e'; });
    }
  }

  // ── Navegar para o scanner ────────────────────────────────────────────────
  Future<void> _abrirScanner() async {
    if (_arquivoAtual == null) {
      _mostrarSnack('Selecione ou crie um arquivo primeiro.');
      return;
    }
    final resultado = await Navigator.push<List<ProdutoEstoque>>(
      context,
      MaterialPageRoute(
        builder: (_) => ScannerScreen(
          produtos: List.from(_produtos),
          arquivoAtual: _arquivoAtual!,
        ),
      ),
    );
    if (resultado != null) {
      setState(() { _produtos = resultado; });
      _salvar();
    }
  }

  // ── Ver lista de produtos ─────────────────────────────────────────────────
  Future<void> _verLista() async {
    if (_arquivoAtual == null) {
      _mostrarSnack('Selecione ou crie um arquivo primeiro.');
      return;
    }
    final resultado = await Navigator.push<List<ProdutoEstoque>>(
      context,
      MaterialPageRoute(
        builder: (_) => ListaScreen(
          produtos: List.from(_produtos),
          arquivoAtual: _arquivoAtual!,
        ),
      ),
    );
    if (resultado != null) {
      setState(() { _produtos = resultado; });
      _salvar();
    }
  }

  // ── Salvar arquivo ────────────────────────────────────────────────────────
  Future<void> _salvar() async {
    if (_arquivoAtual == null) return;
    try {
      await _csvService.salvarArquivo(_produtos, arquivoOrigem: _arquivoAtual);
      setState(() { _mensagem = 'Salvo! ${_produtos.length} produto(s)'; });
    } catch (e) {
      _mostrarSnack('Erro ao salvar: $e');
    }
  }

  // ── Compartilhar arquivo ──────────────────────────────────────────────────
  Future<void> _compartilhar() async {
    if (_arquivoAtual == null) {
      _mostrarSnack('Nenhum arquivo carregado.');
      return;
    }
    await _salvar();
    await _csvService.compartilharArquivo(_arquivoAtual!);
  }

  void _mostrarSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final nomeArquivo = _arquivoAtual != null
        ? _arquivoAtual!.path.split('/').last
        : 'Nenhum arquivo selecionado';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contagem de Estoque'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Exportar / Compartilhar',
            onPressed: _compartilhar,
          ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Card de status do arquivo ───────────────────────────
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _arquivoAtual != null
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: _arquivoAtual != null
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              const Text('Arquivo atual',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            nomeArquivo,
                            style: TextStyle(
                              color: _arquivoAtual != null
                                  ? Colors.black87
                                  : Colors.grey,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_mensagem != null) ...[
                            const SizedBox(height: 6),
                            Text(_mensagem!,
                                style: const TextStyle(color: Colors.green, fontSize: 13)),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Estatísticas ────────────────────────────────────────
                  if (_arquivoAtual != null)
                    Row(
                      children: [
                        _statCard(
                          icon: Icons.inventory_2,
                          label: 'Produtos',
                          valor: '${_produtos.length}',
                          cor: Colors.blue,
                        ),
                        const SizedBox(width: 12),
                        _statCard(
                          icon: Icons.add_shopping_cart,
                          label: 'Total Itens',
                          valor: '${_produtos.fold<int>(0, (s, p) => s + p.quantidade)}',
                          cor: Colors.orange,
                        ),
                      ],
                    ),

                  const SizedBox(height: 32),

                  // ── Botões de ação ──────────────────────────────────────
                  const Text('Arquivo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: _actionButton(
                          icon: Icons.folder_open,
                          label: 'Abrir CSV',
                          onPressed: _selecionarArquivo,
                          outline: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _actionButton(
                          icon: Icons.add,
                          label: 'Novo CSV',
                          onPressed: _criarNovoArquivo,
                          outline: true,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Text('Contagem', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 8),

                  _actionButton(
                    icon: Icons.qr_code_scanner,
                    label: 'Bipar Produto',
                    onPressed: _abrirScanner,
                    big: true,
                  ),

                  const SizedBox(height: 12),

                  _actionButton(
                    icon: Icons.list_alt,
                    label: 'Ver / Editar Lista',
                    onPressed: _verLista,
                    outline: true,
                  ),

                  const SizedBox(height: 12),

                  _actionButton(
                    icon: Icons.save,
                    label: 'Salvar',
                    onPressed: _arquivoAtual != null ? _salvar : null,
                    outline: true,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String valor,
    required Color cor,
  }) {
    return Expanded(
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Row(
            children: [
              Icon(icon, color: cor, size: 28),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(valor,
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold, color: cor)),
                  Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool outline = false,
    bool big = false,
  }) {
    if (outline) {
      return OutlinedButton.icon(
        icon: Icon(icon),
        label: Text(label),
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
    return ElevatedButton.icon(
      icon: Icon(icon, size: big ? 26 : 20),
      label: Text(label, style: TextStyle(fontSize: big ? 17 : 15)),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: big ? 18 : 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
