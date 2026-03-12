import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/produto_estoque.dart';
import '../services/csv_service.dart';

class ListaScreen extends StatefulWidget {
  final List<ProdutoEstoque> produtos;
  final File arquivoAtual;

  const ListaScreen({
    super.key,
    required this.produtos,
    required this.arquivoAtual,
  });

  @override
  State<ListaScreen> createState() => _ListaScreenState();
}

class _ListaScreenState extends State<ListaScreen> {
  final CsvService _csvService = CsvService();
  late List<ProdutoEstoque> _produtos;
  String _busca = '';
  bool _alterado = false;

  @override
  void initState() {
    super.initState();
    _produtos = List.from(widget.produtos);
  }

  List<ProdutoEstoque> get _produtosFiltrados {
    if (_busca.isEmpty) return _produtos;
    return _produtos.where((p) => p.gtin.contains(_busca)).toList();
  }

  // ── Editar quantidade de um produto ──────────────────────────────────────
  Future<void> _editarProduto(ProdutoEstoque produto) async {
    final controller = TextEditingController(text: '${produto.quantidade}');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Quantidade'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('GTIN: ${produto.gtin}',
                style: const TextStyle(
                    fontFamily: 'monospace', fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nova quantidade',
                suffixText: 'un.',
              ),
              onSubmitted: (_) => Navigator.pop(ctx),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    final novaQtd = int.tryParse(controller.text.trim());
    if (novaQtd != null && novaQtd != produto.quantidade) {
      setState(() {
        produto.quantidade = novaQtd;
        _alterado = true;
      });
    }
  }

  // ── Remover produto ───────────────────────────────────────────────────────
  Future<void> _removerProduto(ProdutoEstoque produto) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover produto'),
        content: Text('Remover GTIN ${produto.gtin} da lista?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      setState(() {
        _produtos.remove(produto);
        _alterado = true;
      });
    }
  }

  // ── Adicionar produto manualmente ─────────────────────────────────────────
  Future<void> _adicionarManual() async {
    final gtinCtrl = TextEditingController();
    final qtdCtrl = TextEditingController(text: '1');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adicionar Produto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: gtinCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'GTIN / EAN',
                prefixIcon: Icon(Icons.qr_code),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtdCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Quantidade',
                suffixText: 'un.',
                prefixIcon: Icon(Icons.add_box),
              ),
              onSubmitted: (_) => Navigator.pop(ctx),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Adicionar')),
        ],
      ),
    );

    final gtin = gtinCtrl.text.trim();
    final qtd = int.tryParse(qtdCtrl.text.trim()) ?? 0;
    if (gtin.isNotEmpty && qtd > 0) {
      setState(() {
        _produtos.add(ProdutoEstoque(gtin: gtin, quantidade: qtd));
        _alterado = true;
      });
    }
  }

  // ── Salvar e voltar ───────────────────────────────────────────────────────
  Future<void> _salvarEVoltar() async {
    if (_alterado) {
      await _csvService.salvarArquivo(_produtos, arquivoOrigem: widget.arquivoAtual);
    }
    if (mounted) Navigator.pop(context, _produtos);
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _produtosFiltrados;
    final totalItens = _produtos.fold<int>(0, (s, p) => s + p.quantidade);

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context, _produtos);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Lista (${_produtos.length} produtos)'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _salvarEVoltar,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add_alt),
              tooltip: 'Adicionar manualmente',
              onPressed: _adicionarManual,
            ),
            IconButton(
              icon: Icon(
                Icons.save,
                color: _alterado ? Colors.yellow : Colors.white70,
              ),
              tooltip: 'Salvar',
              onPressed: _salvarEVoltar,
            ),
          ],
        ),
        body: Column(
          children: [
            // ── Resumo ──────────────────────────────────────────────────
            Container(
              color: Colors.blue.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _infoChip(Icons.inventory_2, '${_produtos.length}', 'Produtos'),
                  _infoChip(Icons.add_shopping_cart, '$totalItens', 'Total Itens'),
                ],
              ),
            ),

            // ── Busca ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar por GTIN...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _busca.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _busca = ''),
                        )
                      : null,
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _busca = v.trim()),
              ),
            ),

            // ── Lista ────────────────────────────────────────────────────
            Expanded(
              child: filtrados.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.inventory, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            _busca.isNotEmpty
                                ? 'Nenhum resultado para "$_busca"'
                                : 'Lista vazia.\nBipe produtos ou adicione manualmente.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtrados.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 56),
                      itemBuilder: (ctx, i) {
                        final p = filtrados[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            child: const Icon(Icons.qr_code, size: 18, color: Colors.blue),
                          ),
                          title: Text(
                            p.gtin,
                            style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Registrado: ${_formatarData(p.dataHora)}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.blue.shade200),
                                ),
                                child: Text(
                                  '${p.quantidade} un.',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                                onPressed: () => _editarProduto(p),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                onPressed: () => _removerProduto(p),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _adicionarManual,
          icon: const Icon(Icons.add),
          label: const Text('Adicionar'),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String valor, String label) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blue),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(valor,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  String _formatarData(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}
