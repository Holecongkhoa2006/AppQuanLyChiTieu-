// =============================================================================
// bill_ocr_service.dart — Dịch vụ Bóc tách Bill Chuyển khoản & Hóa đơn OCR v2
// CR404 Expense Manager — FinTech Mobile Architecture
// Công nghệ: Google ML Kit Text Recognition (On-Device, Miễn phí, < 0.5s)
// =============================================================================

import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Kết quả bóc tách thông minh từ Bill chuyển khoản hoặc Hóa đơn
class ScannedBillResult {
  final double amount;
  final String currencyCode; // 'VND' | 'USD' | 'EUR' | 'JPY'
  final DateTime transactionDate;
  final String type; // 'expense' | 'income'
  final String? detectedBankOrWallet;
  final String note;
  final int? suggestedCategoryId;
  final String? suggestedCategoryName;
  final String rawText;

  ScannedBillResult({
    required this.amount,
    this.currencyCode = 'VND',
    required this.transactionDate,
    this.type = 'expense',
    this.detectedBankOrWallet,
    this.note = '',
    this.suggestedCategoryId,
    this.suggestedCategoryName,
    this.rawText = '',
  });

  @override
  String toString() {
    return 'ScannedBillResult(amount: $amount $currencyCode, type: $type, bank: $detectedBankOrWallet, date: $transactionDate, note: "$note", cat: "$suggestedCategoryName")';
  }
}

class BillOcrService {
  BillOcrService._();
  static final BillOcrService instance = BillOcrService._();

  final TextRecognizer _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Quét ảnh Bill chuyển khoản hoặc Hóa đơn
  Future<ScannedBillResult?> scanBillImage({
    required String imagePath,
    List<Map<String, dynamic>>? categoryKeywords,
  }) async {
    final file = File(imagePath);
    if (!await file.exists()) return null;

    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizedText = await _recognizer.processImage(inputImage);
    final fullText = recognizedText.text;

    if (fullText.trim().isEmpty) return null;

    final lines = fullText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // 1. Nhận diện Đơn vị Tiền tệ (Currency)
    final currencyCode = _detectCurrency(fullText);

    // 2. Nhận diện Loại Giao dịch (income vs expense)
    final txType = _detectTransactionType(fullText);

    // 3. Nhận diện Ngân hàng / Ví điện tử
    final detectedBank = _detectBankOrWallet(fullText);

    // 4. Nhận diện Số tiền
    final amount = _extractAmount(lines, currencyCode);

    // 5. Nhận diện Ngày giờ giao dịch
    final transactionDate = _extractDateTime(fullText) ?? DateTime.now();

    // 6. Nhận diện Nội dung chuyển khoản / Tên cửa hàng
    final note = _extractNote(lines);

    // 7. Gợi ý Danh mục tự động theo từ khóa
    final categorySuggestion = _suggestCategory(
      fullText: fullText,
      note: note,
      type: txType,
      categoryKeywords: categoryKeywords,
    );

    return ScannedBillResult(
      amount: amount,
      currencyCode: currencyCode,
      transactionDate: transactionDate,
      type: txType,
      detectedBankOrWallet: detectedBank,
      note: note,
      suggestedCategoryId: categorySuggestion['id'] as int?,
      suggestedCategoryName: categorySuggestion['name'] as String?,
      rawText: fullText,
    );
  }

  /// 1. Nhận diện đơn vị tiền tệ
  String _detectCurrency(String text) {
    final upper = text.toUpperCase();
    if (upper.contains('\$') || upper.contains('USD')) return 'USD';
    if (upper.contains('€') || upper.contains('EUR')) return 'EUR';
    if (upper.contains('¥') || upper.contains('JPY')) return 'JPY';
    if (upper.contains('SGD') || upper.contains('S\$')) return 'SGD';
    if (upper.contains('THB') || upper.contains('฿')) return 'THB';
    if (upper.contains('KRW') || upper.contains('₩')) return 'KRW';
    return 'VND';
  }

  /// 2. Nhận diện Loại Giao dịch: 'income' (tiền vào) hay 'expense' (tiền ra)
  String _detectTransactionType(String text) {
    final lower = text.toLowerCase();
    final incomeKeywords = [
      'nhận tiền',
      'tiền vào',
      'chuyển tiền đến',
      'cộng tiền',
      'giao dịch nhận',
      'người chuyển',
      'received',
      'income',
      'chuyển khoản đến',
      'số dư tăng',
      '+',
    ];

    for (final kw in incomeKeywords) {
      if (lower.contains(kw)) {
        // Kiểm tra xem có dấu trừ rõ ràng trước số tiền không
        if (!lower.contains('chuyển đi') && !lower.contains('thanh toán')) {
          return 'income';
        }
      }
    }
    return 'expense';
  }

  /// 3. Nhận diện Ngân hàng hoặc Ví điện tử tại Việt Nam
  String? _detectBankOrWallet(String text) {
    final lower = text.toLowerCase();

    // Danh mục Ngân hàng phổ biến tại Việt Nam
    if (lower.contains('vietcombank') || lower.contains('vcb') || lower.contains('digibank')) {
      return 'Vietcombank';
    }
    if (lower.contains('mbbank') || lower.contains('mb bank') || lower.contains('quân đội')) {
      return 'MB Bank';
    }
    if (lower.contains('techcombank') || lower.contains('tcb')) {
      return 'Techcombank';
    }
    if (lower.contains('bidv') || lower.contains('smartbanking')) {
      return 'BIDV';
    }
    if (lower.contains('vietinbank') || lower.contains('ipay')) {
      return 'VietinBank';
    }
    if (lower.contains('acb')) {
      return 'ACB';
    }
    if (lower.contains('vpbank') || lower.contains('vp bank') || lower.contains('neo')) {
      return 'VPBank';
    }
    if (lower.contains('tpbank') || lower.contains('tp bank') || lower.contains('tiên phong')) {
      return 'TPBank';
    }
    if (lower.contains('agribank')) {
      return 'Agribank';
    }
    if (lower.contains('sacombank')) {
      return 'Sacombank';
    }
    if (lower.contains('vib')) {
      return 'VIB';
    }
    if (lower.contains('hdbank')) {
      return 'HDBank';
    }
    if (lower.contains('ocb')) {
      return 'OCB';
    }

    // Ví điện tử
    if (lower.contains('momo')) {
      return 'Ví MoMo';
    }
    if (lower.contains('zalopay') || lower.contains('zalo pay')) {
      return 'Ví ZaloPay';
    }
    if (lower.contains('shopeepay') || lower.contains('shopee pay') || lower.contains('airpay')) {
      return 'Ví ShopeePay';
    }
    if (lower.contains('viettel money') || lower.contains('viettelpay')) {
      return 'Viettel Money';
    }

    return null;
  }

  /// 4. Bóc tách Số tiền (Amount) kèm bộ lọc chống nhầm Số tài khoản / Mã giao dịch
  double _extractAmount(List<String> lines, String currencyCode) {
    double bestAmount = 0.0;

    // Pattern nhận diện số tiền có phân cách hàng nghìn (.,)
    // VD: 150,000 | 1.250.000 | 50.000đ | -250,000 VND | $45.50
    final amountPattern = RegExp(
      r'(?:[\+\-]?\s*)(?:[A-Z\$€¥₫đ]{0,3}\s*)?([0-9]{1,3}(?:[.,][0-9]{3})+(?:[.,][0-9]{1,2})?|[0-9]{4,9})(?:\s*(?:VND|VNĐ|đ|₫|\$|EUR|JPY))?',
      caseSensitive: false,
    );

    // Từ khóa ưu tiên cao trên bill/hóa đơn
    final priorityKeywords = [
      'số tiền',
      'thành tiền',
      'tổng cộng',
      'thanh toán',
      'total',
      'amount',
      'tổng thanh toán',
      'giá trị',
      'số tiền giao dịch',
      'số tiền nhận',
    ];

    // Duyệt qua từng dòng tìm dòng có chứa từ khóa số tiền trước
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineLower = line.toLowerCase();

      bool hasKeyword = false;
      for (final kw in priorityKeywords) {
        if (lineLower.contains(kw)) {
          hasKeyword = true;
          break;
        }
      }

      if (hasKeyword) {
        // Tìm số tiền ngay trên dòng này
        final matches = amountPattern.allMatches(line);
        for (final m in matches) {
          final raw = m.group(1);
          if (raw != null) {
            final parsed = _parseCleanNumber(raw, currencyCode);
            if (_isValidAmount(parsed, raw)) {
              return parsed;
            }
          }
        }

        // Hoặc tìm ở dòng ngay tiếp theo (i + 1)
        if (i + 1 < lines.length) {
          final nextLine = lines[i + 1];
          final matchesNext = amountPattern.allMatches(nextLine);
          for (final m in matchesNext) {
            final raw = m.group(1);
            if (raw != null) {
              final parsed = _parseCleanNumber(raw, currencyCode);
              if (_isValidAmount(parsed, raw)) {
                return parsed;
              }
            }
          }
        }
      }
    }

    // Nếu không khớp từ khóa rõ ràng, quét toàn bộ văn bản và lấy số tiền hợp lý lớn nhất
    for (final line in lines) {
      // Bộ lọc loại trừ dòng chứa Mã GD / STK / SĐT
      if (_isNoiseLine(line)) continue;

      final matches = amountPattern.allMatches(line);
      for (final m in matches) {
        final raw = m.group(1);
        if (raw != null) {
          final parsed = _parseCleanNumber(raw, currencyCode);
          if (_isValidAmount(parsed, raw) && parsed > bestAmount) {
            bestAmount = parsed;
          }
        }
      }
    }

    return bestAmount;
  }

  /// Bộ lọc chống nhầm dòng chứa Số tài khoản, Mã tham chiếu, Ngày giờ
  bool _isNoiseLine(String line) {
    final lower = line.toLowerCase();
    if (lower.contains('số tài khoản') ||
        lower.contains('stk') ||
        lower.contains('mã gd') ||
        lower.contains('mã giao dịch') ||
        lower.contains('số tham chiếu') ||
        lower.contains('ref no') ||
        lower.contains('trace') ||
        lower.contains('ft') ||
        lower.contains('sđt') ||
        lower.contains('điện thoại')) {
      return true;
    }
    // Dòng chỉ là chuỗi số dài liên tiếp 9-16 ký tự không dấu chấm/phẩy (STK)
    if (RegExp(r'^\d{9,16}$').hasMatch(line.trim())) {
      return true;
    }
    return false;
  }

  /// Kiểm tra số tiền có hợp lệ không
  bool _isValidAmount(double amount, String raw) {
    // Loại trừ số quá nhỏ (< 1.000 đối với VND) hoặc số 0
    if (amount <= 0) return false;
    // Nếu là chuỗi số liền tù tì không có dấu chấm phẩy và có độ dài từ 9 đến 16 (khả năng là STK ngân hàng)
    if (!raw.contains('.') && !raw.contains(',') && raw.length >= 9 && raw.length <= 16) {
      return false;
    }
    return true;
  }

  /// Parse số tiền dạng text thành double
  double _parseCleanNumber(String raw, String currencyCode) {
    String clean = raw.trim();

    // Đối với USD / EUR: dấu phẩy phân cách nghìn, dấu chấm là thập phân
    if (currencyCode == 'USD' || currencyCode == 'EUR') {
      if (clean.contains(',') && clean.contains('.')) {
        clean = clean.replaceAll(',', '');
      } else if (clean.contains(',')) {
        clean = clean.replaceAll(',', '.');
      }
      return double.tryParse(clean) ?? 0.0;
    }

    // Đối với VND / JPY: thông thường dấu chấm là hàng nghìn, không có phần thập phân
    if (clean.contains('.') && clean.contains(',')) {
      // Dạng 1.250.000,00
      clean = clean.split(',')[0].replaceAll('.', '');
    } else if (clean.contains('.')) {
      clean = clean.replaceAll('.', '');
    } else if (clean.contains(',')) {
      clean = clean.replaceAll(',', '');
    }
    return double.tryParse(clean) ?? 0.0;
  }

  /// 5. Bóc tách Ngày giờ giao dịch (dd/MM/yyyy HH:mm)
  DateTime? _extractDateTime(String text) {
    // Pattern 1: dd/MM/yyyy HH:mm:ss hoặc dd/MM/yyyy HH:mm
    final p1 = RegExp(r'(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?');
    final m1 = p1.firstMatch(text);
    if (m1 != null) {
      final d = int.tryParse(m1.group(1) ?? '') ?? 1;
      final m = int.tryParse(m1.group(2) ?? '') ?? 1;
      final y = int.tryParse(m1.group(3) ?? '') ?? 2026;
      final hr = int.tryParse(m1.group(4) ?? '') ?? 0;
      final min = int.tryParse(m1.group(5) ?? '') ?? 0;
      final sec = int.tryParse(m1.group(6) ?? '') ?? 0;
      return DateTime(y, m, d, hr, min, sec);
    }

    // Pattern 2: HH:mm:ss, dd/MM/yyyy hoặc HH:mm - dd/MM/yyyy
    final p2 = RegExp(r'(\d{1,2}):(\d{2})(?::(\d{2}))?\s*[\,\-]?\s*(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{4})');
    final m2 = p2.firstMatch(text);
    if (m2 != null) {
      final hr = int.tryParse(m2.group(1) ?? '') ?? 0;
      final min = int.tryParse(m2.group(2) ?? '') ?? 0;
      final sec = int.tryParse(m2.group(3) ?? '') ?? 0;
      final d = int.tryParse(m2.group(4) ?? '') ?? 1;
      final m = int.tryParse(m2.group(5) ?? '') ?? 1;
      final y = int.tryParse(m2.group(6) ?? '') ?? 2026;
      return DateTime(y, m, d, hr, min, sec);
    }

    // Pattern 3: Chỉ có ngày dd/MM/yyyy
    final p3 = RegExp(r'(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{4})');
    final m3 = p3.firstMatch(text);
    if (m3 != null) {
      final d = int.tryParse(m3.group(1) ?? '') ?? 1;
      final m = int.tryParse(m3.group(2) ?? '') ?? 1;
      final y = int.tryParse(m3.group(3) ?? '') ?? 2026;
      final now = DateTime.now();
      return DateTime(y, m, d, now.hour, now.minute);
    }

    return null;
  }

  /// 6. Bóc tách Nội dung chuyển khoản / Tên cửa hàng
  String _extractNote(List<String> lines) {
    final noteKeywords = [
      'nội dung chuyển tiền',
      'nội dung chuyển khoản',
      'nội dung giao dịch',
      'nội dung',
      'lời nhắn',
      'diễn giải',
      'lý do',
    ];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lower = line.toLowerCase();

      for (final kw in noteKeywords) {
        if (lower.startsWith(kw) || lower.contains('$kw:')) {
          // Lấy nội dung ngay sau dấu hai chấm
          final colonIdx = line.indexOf(':');
          if (colonIdx != -1 && colonIdx < line.length - 1) {
            final extracted = line.substring(colonIdx + 1).trim();
            if (extracted.isNotEmpty) return extracted;
          }

          // Hoặc lấy ở dòng tiếp theo
          if (i + 1 < lines.length) {
            final nextLine = lines[i + 1].trim();
            if (nextLine.isNotEmpty && !_isNoiseLine(nextLine)) {
              return nextLine;
            }
          }
        }
      }
    }

    // Nếu là hóa đơn bán lẻ siêu thị/nhà hàng, lấy tên thương hiệu ở dòng đầu tiên
    if (lines.isNotEmpty) {
      final firstLine = lines.first;
      if (firstLine.length >= 3 && firstLine.length <= 40 && !_isNoiseLine(firstLine)) {
        return firstLine;
      }
    }

    return 'Giao dịch chuyển khoản';
  }

  /// 7. Tự động gợi ý Danh mục gốc dựa trên từ khóa (Keywords Mapping)
  Map<String, dynamic> _suggestCategory({
    required String fullText,
    required String note,
    required String type,
    List<Map<String, dynamic>>? categoryKeywords,
  }) {
    final target = '${fullText.toLowerCase()} ${note.toLowerCase()}';

    // A. Nếu có danh sách keywords từ Aiven Database truyền vào
    if (categoryKeywords != null && categoryKeywords.isNotEmpty) {
      for (final cat in categoryKeywords) {
        final kwString = (cat['keywords'] ?? '').toString().toLowerCase();
        if (kwString.isNotEmpty) {
          final words = kwString.split(',').map((w) => w.trim()).where((w) => w.isNotEmpty);
          for (final word in words) {
            if (target.contains(word)) {
              return {
                'id': cat['id'],
                'name': cat['name'],
                'type': cat['type'] ?? type,
              };
            }
          }
        }
      }
    }

    // B. Bộ từ điển FinTech mặc định
    if (type == 'income' || target.contains('lương') || target.contains('thưởng') || target.contains('salary')) {
      return {'id': null, 'name': 'Lương / Thu nhập', 'type': 'income'};
    }

    if (target.contains('cơm') ||
        target.contains('phở') ||
        target.contains('bún') ||
        target.contains('cafe') ||
        target.contains('cà phê') ||
        target.contains('trà sữa') ||
        target.contains('highland') ||
        target.contains('starbucks') ||
        target.contains('kfc') ||
        target.contains('lotteria') ||
        target.contains('grabfood') ||
        target.contains('shopeefood') ||
        target.contains('ăn uống') ||
        target.contains('bánh mì') ||
        target.contains('nhà hàng') ||
        target.contains('lẩu') ||
        target.contains('nướng')) {
      return {'id': null, 'name': 'Ăn uống', 'type': 'expense'};
    }

    if (target.contains('shopee') ||
        target.contains('lazada') ||
        target.contains('tiktok') ||
        target.contains('winmart') ||
        target.contains('coopmart') ||
        target.contains('bách hóa') ||
        target.contains('siêu thị') ||
        target.contains('quần áo') ||
        target.contains('giày') ||
        target.contains('mua sắm') ||
        target.contains('thời trang') ||
        target.contains('uniqlo') ||
        target.contains('zara')) {
      return {'id': null, 'name': 'Mua sắm', 'type': 'expense'};
    }

    if (target.contains('điện') ||
        target.contains('nước') ||
        target.contains('internet') ||
        target.contains('wifi') ||
        target.contains('viettel') ||
        target.contains('fpt') ||
        target.contains('vnpt') ||
        target.contains('tiền nhà') ||
        target.contains('phòng trọ') ||
        target.contains('chung cư') ||
        target.contains('thuê nhà')) {
      return {'id': null, 'name': 'Nhà cửa', 'type': 'expense'};
    }

    if (target.contains('xăng') ||
        target.contains('petrolimex') ||
        target.contains('grab') ||
        target.contains('be') ||
        target.contains('xanh sm') ||
        target.contains('taxi') ||
        target.contains('gửi xe') ||
        target.contains('vé xe') ||
        target.contains('bãi đỗ') ||
        target.contains('vé máy bay') ||
        target.contains('vé tàu')) {
      return {'id': null, 'name': 'Vận chuyển', 'type': 'expense'};
    }

    if (target.contains('cgv') ||
        target.contains('lotte cinema') ||
        target.contains('netflix') ||
        target.contains('spotify') ||
        target.contains('vé xem phim') ||
        target.contains('du lịch') ||
        target.contains('karaoke') ||
        target.contains('bida') ||
        target.contains('game')) {
      return {'id': null, 'name': 'Giải trí', 'type': 'expense'};
    }

    if (target.contains('bệnh viện') ||
        target.contains('thuốc') ||
        target.contains('nhà thuốc') ||
        target.contains('pharmacity') ||
        target.contains('long châu') ||
        target.contains('khám') ||
        target.contains('bác sĩ') ||
        target.contains('gym') ||
        target.contains('yoga') ||
        target.contains('fitness')) {
      return {'id': null, 'name': 'Sức khỏe', 'type': 'expense'};
    }

    return {'id': null, 'name': 'Khác', 'type': 'expense'};
  }

  void dispose() {
    _recognizer.close();
  }
}

