import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/produto_estoque.dart';
import '../services/csv_service.dart';

class ScannerScreen extends StatefulWidget {
  final List<ProdutoEstoque> produtos;
  final File arquivoAtual;

  const ScannerScreen({
    super.key,
    required this.produtos,
    required this.arquivoAtual,
  });

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final CsvService _csvService = CsvService();
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  late List<ProdutoEstoque> _produtos;

  String? _gtinBipado;
  bool _scanAtivo = true;
  bool _processando = false;
  int _totalBipados = 0;

  @override
  void initState() {
    super.initState();
    _produtos = List.from(widget.produtos);
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  // ── Callback quando um código é detectado ────────────────────────────────
  void _onDetect(BarcodeCapture capture) {
    if (!_scanAtivo || _processando) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final codigo = barcodes.first.rawValue;
    if (codigo == null || codigo.isEmpty) return;

    setState(() {
      _scanAtivo = false;
      _gtinBipado = codigo;
    });

    HapticFeedback.mediumImpact();
    _mostrarDialogQuantidade(codigo);
  }

  // ── Dialog para digitar a quantidade ─────────────────────────────────────
  Future<void> _mostrarDialogQuantidade(String gtin) async {
    setState(() { _processando = true; });

    final controller = TextEditingController(text: '1');
    final existente = _produtos.where((p) => p.gtin == gtin).firstOrNull;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.qr_code, color: Color(0xFF1565C0)),
            const SizedBox(width: 8),
            const Text('Produto Bipado'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Text('GTIN: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Text(gtin,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 15)),
                  ),
                ],
              ),
            ),
            if (existente != null) ...[
              const SizedBox(height: 6),
              Text(
                'Já na lista: ${existente.quantidade} un.',
                style: const TextStyle(color: Colors.orange, fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
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
          TextButton(
            onPressed: () {
              controller.text = '';
              Navigator.pop(ctx);
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Confirmar'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );

    final qtdTexto = controller.text.trim();
    if (qtdTexto.isNotEmpty) {
      final qtd = int.tryParse(qtdTexto) ?? 0;
      if (qtd > 0) {
        _adicionarOuAtualizar(gtin, qtd);
      }
    }

    setState(() {
      _processando = false;
      _scanAtivo = true;
      _gtinBipado = null;
    });
  }

  // ── Adicionar ou somar quantidade ao produto ──────────────────────────────
  void _adicionarOuAtualizar(String gtin, int quantidade) {
    final idx = _produtos.indexWhere((p) => p.gtin == gtin);
    if (idx >= 0) {
      // pergunta se soma ou substitui
      _mostrarDialogSomarOuSubstituir(gtin, quantidade, idx);
    } else {
      setState(() {
        _produtos.add(ProdutoEstoque(gtin: gtin, quantidade: quantidade));
        _totalBipados++;
      });
      _salvarAutomatico();
      _mostrarConfirmacao('Produto adicionado!', quantidade);
    }
  }

  Future<void> _mostrarDialogSomarOuSubstituir(
      String gtin, int novaQtd, int idx) async {
    final opcao = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Produto já existe'),
        content: Text(
          'GTIN $gtin já está na lista com ${_produtos[idx].quantidade} un.\n\n'
          'O que deseja fazer?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancelar'),
            child: const Text('Cancelar'),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: Text('Somar (+$novaQtd)'),
            onPressed: () => Navigator.pop(ctx, 'somar'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.swap_horiz),
            label: Text('Substituir ($novaQtd)'),
            onPressed: () => Navigator.pop(ctx, 'substituir'),
          ),
        ],
      ),
    );

    if (opcao == 'somar') {
      setState(() {
        _produtos[idx].quantidade += novaQtd;
        _totalBipados++;
      });
      _salvarAutomatico();
      _mostrarConfirmacao('Quantidade somada!', _produtos[idx].quantidade);
    } else if (opcao == 'substituir') {
      setState(() {
        _produtos[idx].quantidade = novaQtd;
        _totalBipados++;
      });
      _salvarAutomatico();
      _mostrarConfirmacao('Quantidade atualizada!', novaQtd);
    }
  }

  // ── Auto-save após cada bipagem ───────────────────────────────────────────
  Future<void> _salvarAutomatico() async {
    try {
      await _csvService.salvarArquivo(_produtos, arquivoOrigem: widget.arquivoAtual);
    } catch (_) {}
  }

  void _mostrarConfirmacao(String msg, int qtd) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text('$msg  Qtd: $qtd un.'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Digitar GTIN manualmente ──────────────────────────────────────────────
  Future<void> _digitarManual() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Digitar GTIN'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Código GTIN / EAN',
            prefixIcon: Icon(Icons.keyboard),
          ),
          onSubmitted: (_) => Navigator.pop(ctx),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
    final gtin = controller.text.trim();
    if (gtin.isNotEmpty) {
      setState(() { _scanAtivo = false; });
      await _mostrarDialogQuantidade(gtin);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scanner — $_totalBipados bipado(s)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.keyboard),
            tooltip: 'Digitar manualmente',
            onPressed: _digitarManual,
          ),
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _scannerController.torchState,
              builder: (_, state, __) => Icon(
                state == TorchState.on ? Icons.flash_on : Icons.flash_off,
              ),
            ),
            tooltip: 'Lanterna',
            onPressed: () => _scannerController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.check_circle),
            tooltip: 'Concluir',
            onPressed: () => Navigator.pop(context, _produtos),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Área do scanner ─────────────────────────────────────────────
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: _onDetect,
                ),
                // overlay de mira
                Center(
                  child: Container(
                    width: 260,
                    height: 160,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _gtinBipado != null ? Colors.green : Colors.white,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                // instrução
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _scanAtivo
                            ? 'Aponte para o código de barras'
                            : 'Aguardando...',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Últimos produtos bipados ─────────────────────────────────────
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Container(
                  color: Colors.grey.shade200,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_produtos.length} produto(s) na lista',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Concluir'),
                        onPressed: () => Navigator.pop(context, _produtos),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _produtos.isEmpty
                      ? const Center(
                          child: Text(
                            'Nenhum produto bipado ainda',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _produtos.length,
                          reverse: true,
                          itemBuilder: (ctx, i) {
                            final p = _produtos[_produtos.length - 1 - i];
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.qr_code, size: 20),
                              title: Text(p.gtin,
                                  style: const TextStyle(fontFamily: 'monospace')),
                              trailing: Chip(
                                label: Text('${p.quantidade} un.',
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                                backgroundColor: Colors.blue.shade50,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
