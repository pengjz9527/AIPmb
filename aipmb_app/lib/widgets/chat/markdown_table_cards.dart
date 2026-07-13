import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';

/// 将 Markdown 表格文本转换为卡片列表展示（适配手机屏幕）
class MarkdownTableCards extends StatelessWidget {
  final String tableText;

  const MarkdownTableCards({super.key, required this.tableText});

  @override
  Widget build(BuildContext context) {
    final rows = _parseTable(tableText);
    if (rows.length < 2) {
      // 不是有效表格，返回原始文本
      return Text(tableText, style: TextStyle(fontSize: 13, color: Colors.grey.shade800));
    }

    final headers = rows.first;
    final dataRows = rows.skip(1).where((r) => r.isNotEmpty && !_isSeparatorRow(r)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: dataRows.map((row) => _buildCard(context, headers, row)).toList(),
    );
  }

  /// 解析 Markdown 表格
  List<List<String>> _parseTable(String text) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final rows = <List<String>>[];
    for (final line in lines) {
      if (line.startsWith('|')) {
        final cells = line
            .split('|')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .toList();
        if (cells.isNotEmpty) rows.add(cells);
      }
    }
    return rows;
  }

  /// 是否为分隔行（|---|---|）
  bool _isSeparatorRow(List<String> row) {
    return row.every((cell) => cell.replaceAll('-', '').isEmpty);
  }

  /// 构建单条数据卡片
  Widget _buildCard(BuildContext context, List<String> headers, List<String> row) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 第一列作为卡片标题（加粗显示）
            if (row.isNotEmpty)
              _buildMarkdownText(
                row.first,
                TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            if (row.isNotEmpty) const SizedBox(height: 8),
            // 其余列作为键值对
            ..._buildKeyValueRows(headers, row),
          ],
        ),
      ),
    );
  }

  /// 渲染 Markdown 文本（支持粗体等简单格式）
  Widget _buildMarkdownText(String text, TextStyle baseStyle) {
    // 处理粗体 **text**
    final boldPattern = RegExp(r'\*\*(.*?)\*\*');
    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in boldPattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: baseStyle,
        ));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: baseStyle.copyWith(fontWeight: FontWeight.w700),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: baseStyle));
    }

    if (spans.isEmpty) {
      return Text(text, style: baseStyle);
    }

    return RichText(text: TextSpan(children: spans));
  }

  /// 构建键值对行
  List<Widget> _buildKeyValueRows(List<String> headers, List<String> row) {
    final widgets = <Widget>[];
    for (int i = 1; i < headers.length && i < row.length; i++) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标签
              Container(
                constraints: const BoxConstraints(minWidth: 60),
                child: Text(
                  '${headers[i]}：',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // 值
              Expanded(
                child: _buildMarkdownText(
                  row[i],
                  TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }
}

/// Markdown 内容处理器：检测表格并转换为卡片
class MobileMarkdownRenderer {
  /// 将 Markdown 文本中的表格转换为卡片列表，其余内容保持不变
  static List<Widget> buildWidgets(BuildContext context, String markdownText, {MarkdownConfig? config}) {
    final widgets = <Widget>[];
    final lines = markdownText.split('\n');

    final buffer = StringBuffer();
    String? tableBuffer;
    bool inTable = false;

    for (final line in lines) {
      final trimmed = line.trim();

      if (trimmed.startsWith('|')) {
        // 表格行
        if (!inTable) {
          // 先输出之前的非表格内容
          if (buffer.isNotEmpty) {
            widgets.add(_buildTextBlock(buffer.toString(), config: config));
            buffer.clear();
          }
          inTable = true;
          tableBuffer = trimmed;
        } else {
          tableBuffer = '$tableBuffer\n$trimmed';
        }
      } else {
        if (inTable) {
          // 表格结束，输出卡片
          if (tableBuffer != null && tableBuffer.isNotEmpty) {
            widgets.add(MarkdownTableCards(tableText: tableBuffer));
          }
          inTable = false;
          tableBuffer = null;
        }
        buffer.writeln(line);
      }
    }

    // 处理末尾内容
    if (inTable && tableBuffer != null && tableBuffer.isNotEmpty) {
      widgets.add(MarkdownTableCards(tableText: tableBuffer));
    } else if (buffer.isNotEmpty) {
      widgets.add(_buildTextBlock(buffer.toString(), config: config));
    }

    return widgets;
  }

  static Widget _buildTextBlock(String text, {MarkdownConfig? config}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();
    // 使用 MarkdownBlock 渲染非表格内容，支持标题、粗体等格式
    return MarkdownBlock(data: trimmed, config: config ?? MarkdownConfig.defaultConfig);
  }
}
