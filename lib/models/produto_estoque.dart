class ProdutoEstoque {
  final String gtin;
  int quantidade;
  final DateTime dataHora;

  ProdutoEstoque({
    required this.gtin,
    required this.quantidade,
    DateTime? dataHora,
  }) : dataHora = dataHora ?? DateTime.now();

  /// Cria a partir de uma linha CSV
  factory ProdutoEstoque.fromCsv(List<dynamic> row) {
    return ProdutoEstoque(
      gtin: row[0].toString().trim(),
      quantidade: int.tryParse(row[1].toString().trim()) ?? 0,
      dataHora: row.length > 2
          ? DateTime.tryParse(row[2].toString().trim()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// Converte para linha CSV
  List<dynamic> toCsvRow() => [gtin, quantidade, dataHora.toIso8601String()];

  @override
  String toString() => 'ProdutoEstoque(gtin: $gtin, quantidade: $quantidade)';
}
