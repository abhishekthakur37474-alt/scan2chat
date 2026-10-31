import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'phone_extractor.dart';

/// Everything read from one business card.
class CardInfo {
  final List<String> numbers; // 10-digit numbers
  final String? name;
  final String? email;

  const CardInfo({required this.numbers, this.name, this.email});
}

/// Pulls numbers, email and (scored guess) person name out of OCR text.
class CardParser {
  static final RegExp _email = RegExp(
    r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(?:\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}',
  );
  static final RegExp _nameWord = RegExp(r"^[A-Za-z][A-Za-z.'\-]*$");

  /// A name must score at least this much, otherwise it is left blank
  /// (blank is better than a wrong name).
  static const _minScore = 3.5;

  static final _titles = <String>{'mr', 'mrs', 'ms', 'dr', 'shri', 'smt', 'er', 'prof', 'ca', 'adv'};

  /// Designation words. A line next to one of these is very likely the person's name.
  static final _designations = <String>{
    'manager', 'director', 'proprietor', 'prop', 'owner', 'ceo', 'founder',
    'cofounder', 'partner', 'md', 'gm', 'engineer', 'executive', 'head',
    'sales', 'marketing', 'consultant', 'advisor', 'officer', 'president',
    'vice', 'chairman', 'secretary', 'accountant', 'supervisor', 'proprietress',
    'signatory', 'representative', 'incharge', 'operations', 'business',
  };

  /// Words that show a line is a company, designation or address - never a person name.
  static final _blocked = <String>{
    ..._designations,
    'pvt', 'ltd', 'limited', 'llp', 'inc', 'corp', 'company', 'co', 'and',
    'enterprises', 'enterprise', 'industries', 'industry', 'traders', 'trader',
    'trading', 'services', 'service', 'solutions', 'technologies',
    'technology', 'tech', 'infotech', 'systems', 'group', 'associates',
    'consultants', 'consultancy', 'office', 'road', 'street', 'nagar', 'near',
    'plaza', 'floor', 'city', 'delhi', 'india', 'mumbai', 'tower', 'market',
    'shop', 'plot', 'sector', 'phase', 'building', 'complex', 'colony', 'tel',
    'mob', 'mobile', 'phone', 'email', 'address', 'fax', 'gst', 'website',
    'dealer', 'authorised', 'authorized', 'manufacturer', 'supplier',
    'exporter', 'importer', 'private', 'works', 'store', 'stores', 'agency',
    'agencies', 'mart', 'gas', 'motors', 'electricals', 'electronics',
    'hardware', 'jewellers', 'jewelers', 'pharma', 'pharmacy', 'medical',
    'hospital', 'clinic', 'school', 'college', 'institute', 'academy',
    'travels', 'tours', 'transport', 'logistics', 'construction',
    'constructions', 'builders', 'developers', 'realty', 'properties', 'infra',
    'labs', 'laboratory', 'foods', 'food', 'sweets', 'bakery', 'restaurant',
    'hotel', 'garments', 'fashion', 'textiles', 'furniture', 'interiors',
    'printers', 'printing', 'press', 'digital', 'media', 'studio', 'creations',
    'impex', 'exports', 'overseas', 'global', 'international', 'national',
    'engineering', 'fabrication', 'machinery', 'tools', 'packaging', 'plastics',
    'chemicals', 'steel', 'cement', 'paints', 'agro', 'seeds', 'fertilizers',
    'insurance', 'finance', 'financial', 'bank', 'capital', 'investments',
    'ask', 'gemini', 'google', 'chrome', 'search', 'share', 'copy', 'save',
    'download', 'open', 'click', 'tap', 'menu', 'settings', 'chat', 'whatsapp',
    'scan', 'scanner', 'real', 'estate', 'homes', 'house', 'property',
    'advertising', 'marketing', 'events', 'communication', 'communications',
  };

  static final _surnames = <String>{
    'sharma', 'verma', 'gupta', 'singh', 'kumar', 'jain', 'agarwal', 'aggarwal',
    'agrawal', 'mehta', 'shah', 'patel', 'yadav', 'khan', 'reddy', 'rao', 'nair',
    'iyer', 'das', 'roy', 'joshi', 'mishra', 'misra', 'pandey', 'chauhan',
    'bansal', 'goyal', 'garg', 'malhotra', 'kapoor', 'kapur', 'arora', 'saxena',
    'tiwari', 'thakur', 'chaudhary', 'choudhary', 'chopra', 'bhatia', 'sethi',
    'khanna', 'mittal', 'singhal', 'gill', 'sandhu', 'dhawan', 'grover',
    'anand', 'bhardwaj', 'srivastava', 'dubey', 'dwivedi', 'trivedi', 'tripathi',
    'shukla', 'pathak', 'rathore', 'rajput', 'solanki', 'chavan', 'patil',
    'deshmukh', 'kulkarni', 'jha', 'sinha', 'mukherjee', 'banerjee', 'ghosh',
    'bose', 'sen', 'dutta', 'pillai', 'menon', 'naidu', 'gowda', 'ahmed',
    'ansari', 'qureshi', 'siddiqui', 'sheikh', 'shaikh', 'mansuri', 'bhatt',
    'kohli', 'luthra', 'walia', 'sood', 'oberoi', 'tyagi', 'rana', 'mann',
    'dahiya', 'hooda', 'sehrawat', 'malik', 'bhalla', 'batra', 'narula',
  };

  static final _firstNames = <String>{
    'rahul', 'amit', 'ajay', 'vijay', 'sanjay', 'rajesh', 'suresh', 'ramesh',
    'mukesh', 'manoj', 'anil', 'sunil', 'deepak', 'vikas', 'rohit', 'ankit',
    'nitin', 'pankaj', 'pradeep', 'naveen', 'mohit', 'sachin', 'gaurav',
    'arun', 'ashok', 'vinod', 'sandeep', 'neeraj', 'praveen', 'kapil',
    'manish', 'rakesh', 'dinesh', 'mahesh', 'yogesh', 'harish', 'hitesh',
    'jitendra', 'surender', 'surendra', 'mohammad', 'mohd', 'md', 'ravi',
    'raj', 'priya', 'pooja', 'neha', 'anita', 'sunita', 'rekha', 'seema',
    'kavita', 'meena', 'ritu', 'anjali', 'sonia', 'nisha', 'vivek', 'varun',
    'tarun', 'karan', 'arjun', 'akash', 'aakash', 'abhishek', 'ashish',
    'mayank', 'lalit', 'sumit', 'sudhir', 'subhash', 'rajiv', 'rajendra',
    'narender', 'narendra', 'virender', 'devender', 'mahender', 'ramesh',
    'kamal', 'nikhil', 'vishal', 'vipin', 'sameer', 'faisal', 'imran',
    'irfan', 'salman', 'rizwan', 'shahid', 'harpreet', 'gurpreet', 'jaspreet',
    'manpreet', 'amandeep', 'kuldeep', 'parveen', 'shivam', 'saurabh',
  };

  static CardInfo parse(String text) => CardInfo(
        numbers: PhoneExtractor.findAll(text),
        name: findName(text.split('\n')),
        email: findEmail(text),
      );

  /// Uses ML Kit lines (in reading order) for better name detection.
  static CardInfo parseRecognized(RecognizedText rt) {
    final lines = <String>[
      for (final b in rt.blocks)
        for (final l in b.lines) l.text.trim(),
    ]..removeWhere((l) => l.isEmpty);

    return CardInfo(
      numbers: PhoneExtractor.findAll(rt.text),
      name: findName(lines),
      email: findEmail(rt.text),
    );
  }

  static String? findEmail(String text) {
    for (final line in text.split('\n')) {
      // OCR often adds spaces around '@'
      final cleaned = line.replaceAll(RegExp(r'\s*@\s*'), '@');
      final m = _email.firstMatch(cleaned);
      if (m != null) return m.group(0)!.toLowerCase();
    }
    return null;
  }

  /// Scores every line (and every pair of one-word lines) that could be a
  /// person name and returns the best one. Returns null if nothing scores high enough.
  static String? findName(List<String> rawLines) {
    final lines = rawLines.map((l) => l.trim()).toList();

    String? best;
    double bestScore = 0;

    void consider(List<String> words, bool hadTitle, int start, int span) {
      final score = _score(words, hadTitle, lines, start, span);
      if (score > bestScore) {
        bestScore = score;
        best = words.map(_fixCase).join(' ');
      }
    }

    for (var i = 0; i < lines.length; i++) {
      final cand = _candidate(lines[i]);
      if (cand != null) consider(cand.words, cand.hadTitle, i, 1);

      // First and last name printed on two separate lines (e.g. "JHANVI" / "RAO").
      if (i + 1 < lines.length) {
        final a = _singleWord(lines[i]);
        final b = _singleWord(lines[i + 1]);
        if (a != null && b != null) consider([a, b], false, i, 2);
      }
    }

    return bestScore >= _minScore ? best : null;
  }

  static double _score(
    List<String> words,
    bool hadTitle,
    List<String> lines,
    int start,
    int span,
  ) {
    final lowerWords = words.map((w) => w.toLowerCase().replaceAll('.', '')).toList();
    double score = 0;

    if (hadTitle) score += 3; // "Mr. ...", "Dr. ..."

    final allTitleCase = words.every(_isTitleCase);
    final allCaps = words.every((w) => w == w.toUpperCase());
    if (allTitleCase) {
      score += 2;
    } else if (allCaps) {
      score += 0.5; // ALL CAPS is often a company logo line
    }

    if (words.length == 2 || words.length == 3) score += 1;

    if (lowerWords.any(_surnames.contains)) score += 3;
    if (_firstNames.contains(lowerWords.first)) score += 2;

    // Name sits right next to a designation ("Manager", "Proprietor"...)
    final prev = start > 0 ? lines[start - 1] : '';
    final next = start + span < lines.length ? lines[start + span] : '';
    if (_hasDesignation(prev) || _hasDesignation(next)) score += 4;

    score -= start * 0.1; // slight preference for lines higher on the card
    return score;
  }

  /// Only plain text lines count. "sales@x.com" must NOT count as the word "sales".
  static bool _hasDesignation(String line) {
    if (line.isEmpty || RegExp(r'[@\d]').hasMatch(line)) return false;
    final lower = line.toLowerCase();
    if (lower.contains('www') || lower.contains('.com') || lower.contains('.in')) {
      return false;
    }
    return lower.split(RegExp(r'[^a-z]+')).any(_designations.contains);
  }

  /// A line with exactly one alphabetic word that could be half of a name.
  static String? _singleWord(String line) {
    if (!RegExp(r"^[A-Za-z][A-Za-z'\-]{1,19}$").hasMatch(line)) return null;
    if (_blocked.contains(line.toLowerCase())) return null;
    return line;
  }

  /// Returns the words if the line could be a name, else null.
  static ({List<String> words, bool hadTitle})? _candidate(String line) {
    if (line.isEmpty || line.length > 32) return null;
    if (RegExp(r'[\d@/:,|&]').hasMatch(line)) return null;

    final lower = line.toLowerCase();
    if (lower.contains('www') || lower.contains('.com') || lower.contains('.in')) {
      return null;
    }

    var words = line.split(RegExp(r'\s+'));
    var hadTitle = false;
    if (words.isNotEmpty && _titles.contains(words.first.toLowerCase().replaceAll('.', ''))) {
      words = words.sublist(1);
      hadTitle = true;
    }
    if (words.length < 2 || words.length > 4) return null;
    if (!words.every(_nameWord.hasMatch)) return null;
    if (words.any((w) => _blocked.contains(w.toLowerCase().replaceAll('.', '')))) {
      return null;
    }
    return (words: words, hadTitle: hadTitle);
  }

  static bool _isTitleCase(String w) {
    if (w.length == 1) return w == w.toUpperCase(); // initial
    if (w.contains('.')) return w[0] == w[0].toUpperCase(); // "R.K."
    return w[0] == w[0].toUpperCase() && w.substring(1) == w.substring(1).toLowerCase();
  }

  static String _fixCase(String w) {
    if (w.length > 1 && w == w.toUpperCase() && !w.contains('.')) {
      return w[0] + w.substring(1).toLowerCase();
    }
    return w;
  }
}