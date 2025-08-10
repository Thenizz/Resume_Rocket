/// ResumeRocket - Starter Flutter app (single-file example)
/// This app is intentionally simple so you can build an APK easily.
/// It stores resumes locally and can export a PDF using the `pdf` + `printing` packages.
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

void main() {
  runApp(ResumeRocketApp());
}

class ResumeRocketApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ResumeRocket',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> resumes = [];
  bool premiumEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('resumes') ?? '[]';
    final list = jsonDecode(raw) as List<dynamic>;
    final prem = prefs.getBool('admin_premium') ?? false;
    setState(() {
      resumes = List<Map<String, dynamic>>.from(list.map((e) => Map<String, dynamic>.from(e)));
      premiumEnabled = prem;
    });
  }

  Future<void> _saveAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('resumes', jsonEncode(resumes));
  }

  void _createNew() {
    final blank = {
      'title': 'Untitled Resume',
      'name': '',
      'email': '',
      'phone': '',
      'summary': '',
      'skills': '',
      'experience': [
        {'role': '', 'company': '', 'years': '', 'desc': ''}
      ],
      'education': [
        {'school': '', 'degree': '', 'years': ''}
      ],
      'template': 'ats_classic'
    };
    setState(() {
      resumes.insert(0, blank);
    });
    _saveAll();
  }

  void _editResume(int index) async {
    final updated = await Navigator.push(context, MaterialPageRoute(builder: (_) => EditorScreen(resume: resumes[index], premiumEnabled: premiumEnabled)));
    if (updated != null && updated is Map<String, dynamic>) {
      setState(() {
        resumes[index] = updated;
      });
      _saveAll();
    }
  }

  void _deleteResume(int index) {
    setState(() {
      resumes.removeAt(index);
    });
    _saveAll();
  }

  void _togglePremium() async {
    final prefs = await SharedPreferences.getInstance();
    final newVal = !premiumEnabled;
    await prefs.setBool('admin_premium', newVal);
    setState(() {
      premiumEnabled = newVal;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Admin premium set to: \$newVal')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ResumeRocket'),
        actions: [
          IconButton(icon: Icon(Icons.admin_panel_settings), tooltip: 'Admin (toggle premium)', onPressed: _togglePremium),
          IconButton(icon: Icon(Icons.refresh), onPressed: _loadAll),
        ],
      ),
      body: resumes.isEmpty ? Center(child: Text('No resumes yet — tap + to create')) :
      ListView.builder(
        itemCount: resumes.length,
        itemBuilder: (context, i) {
          final r = resumes[i];
          return ListTile(
            title: Text(r['title'] ?? 'Untitled'),
            subtitle: Text(r['name'] ?? ''),
            trailing: PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') _editResume(i);
                if (v == 'delete') _deleteResume(i);
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
            onTap: () => _editResume(i),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: _createNew, child: Icon(Icons.add), tooltip: 'Create new resume'),
    );
  }
}

class EditorScreen extends StatefulWidget {
  final Map<String, dynamic> resume;
  final bool premiumEnabled;
  EditorScreen({required this.resume, required this.premiumEnabled});
  @override
  _EditorScreenState createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late Map<String, dynamic> r;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    r = Map<String, dynamic>.from(widget.resume);
  }

  void _saveAndExit() {
    Navigator.pop(context, r);
  }

  void _addExperience() {
    setState(() {
      (r['experience'] as List).add({'role':'','company':'','years':'','desc':''});
    });
  }

  void _removeExperience(int idx) {
    setState(() {
      (r['experience'] as List).removeAt(idx);
    });
  }

  void _aiRewriteSummary() {
    final original = (r['summary'] ?? '').toString();
    final improved = _mockRewrite(original);
    setState(() {
      r['summary'] = improved;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Summary improved (offline mock)')));
  }

  String _mockRewrite(String input) {
    if (input.trim().isEmpty) return input;
    final parts = input.split(RegExp(r'[.!?]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final bullets = parts.map((p) => '- ' + (p.length > 80 ? p.substring(0,80) + '…' : p)).toList();
    return bullets.join('\n');
  }

  void _selectTemplate() async {
    final choice = await showModalBottomSheet<String>(context: context, builder: (_) {
      return SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(title: Text('ATS Classic (free)'), onTap: () => Navigator.pop(context, 'ats_classic')),
        ListTile(title: Text('Modern Clean (free)'), onTap: () => Navigator.pop(context, 'modern_clean')),
        ListTile(title: Text('Creative Visual (premium)'), subtitle: Text('Requires premium'), onTap: () => Navigator.pop(context, 'creative_visual')),
        SizedBox(height:16),
      ]));
    });
    if (choice != null) {
      final premiumTemplates = ['creative_visual'];
      if (premiumTemplates.contains(choice) && !widget.premiumEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('This template is premium. Use Admin toggle to enable for testing.')));
        return;
      }
      setState(() {
        r['template'] = choice;
      });
    }
  }

  void _previewPdf() async {
    final bytes = await _generatePdfBytes(r);
    await Printing.sharePdf(bytes: bytes, filename: '${(r['title'] ?? 'resume').toString().replaceAll(' ', '_')}.pdf');
  }

  Future<Uint8List> _generatePdfBytes(Map<String, dynamic> resume) async {
    final pdf = pw.Document();
    final template = (resume['template'] ?? 'ats_classic').toString();
    if (template == 'ats_classic') {
      pdf.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, build: (pw.Context ctx) {
        return [
          pw.Header(level:0, child: pw.Text(resume['name'] ?? '', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
          pw.Text('${resume['email'] ?? ''} • ${resume['phone'] ?? ''}'),
          pw.SizedBox(height:8),
          pw.Text('Summary', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.Text(resume['summary'] ?? ''),
          pw.SizedBox(height:8),
          pw.Text('Experience', style: pw.TextStyle(fontSize:14, fontWeight: pw.FontWeight.bold)),
          pw.Column(children: List<pw.Widget>.from((resume['experience'] as List<dynamic>).map((e) {
            return pw.Container(padding: pw.EdgeInsets.only(bottom:6), child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('${e['role'] ?? ''} • ${e['company'] ?? ''}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('${e['years'] ?? ''}'),
                pw.Text('${e['desc'] ?? ''}'),
              ]
            ));
          }))),
          pw.SizedBox(height:8),
          pw.Text('Education', style: pw.TextStyle(fontSize:14, fontWeight: pw.FontWeight.bold)),
          pw.Column(children: List<pw.Widget>.from((resume['education'] as List<dynamic>).map((e) {
            return pw.Container(padding: pw.EdgeInsets.only(bottom:6), child: pw.Text('${e['degree'] ?? ''} — ${e['school'] ?? ''} (${e['years'] ?? ''})'));
          }))),
          pw.SizedBox(height:8),
          pw.Text('Skills', style: pw.TextStyle(fontSize:14, fontWeight: pw.FontWeight.bold)),
          pw.Text(resume['skills'] ?? ''),
        ];
      }));
    } else {
      pdf.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, build: (pw.Context ctx) {
        return [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(resume['name'] ?? '', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height:4),
              pw.Text('${resume['email'] ?? ''} • ${resume['phone'] ?? ''}'),
            ]),
          ]),
          pw.Divider(),
          pw.SizedBox(height:6),
          pw.Text('Professional Profile', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.Text(resume['summary'] ?? ''),
          pw.SizedBox(height:8),
          pw.Text('Experience', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.Column(children: List<pw.Widget>.from((resume['experience'] as List<dynamic>).map((e) {
            return pw.Container(padding: pw.EdgeInsets.only(bottom:6), child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('${e['role'] ?? ''}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Row(children: [pw.Expanded(child: pw.Text('${e['company'] ?? ''}')), pw.Text('${e['years'] ?? ''}')]),
                pw.Text('${e['desc'] ?? ''}'),
              ]
            ));
          }))),
          pw.SizedBox(height:8),
          pw.Text('Education', style: pw.TextStyle(fontSize:12, fontWeight: pw.FontWeight.bold)),
          pw.Column(children: List<pw.Widget>.from((resume['education'] as List<dynamic>).map((e) {
            return pw.Container(padding: pw.EdgeInsets.only(bottom:6), child: pw.Text('${e['degree'] ?? ''} — ${e['school'] ?? ''} (${e['years'] ?? ''})'));
          }))),
          pw.SizedBox(height:8),
          pw.Text('Skills', style: pw.TextStyle(fontSize:12, fontWeight: pw.FontWeight.bold)),
          pw.Text(resume['skills'] ?? ''),
        ];
      }));
    }
    final bytes = await pdf.save();
    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Editor — ${(r['title'] ?? 'Untitled')}'), actions: [
        IconButton(icon: Icon(Icons.picture_as_pdf), onPressed: _previewPdf),
        IconButton(icon: Icon(Icons.save), onPressed: _saveAndExit),
        IconButton(icon: Icon(Icons.format_paint), onPressed: _selectTemplate),
      ]),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextFormField(initialValue: r['title'] ?? 'Untitled Resume', decoration: InputDecoration(labelText: 'Resume Title'), onChanged: (v) => r['title'] = v),
            SizedBox(height:8),
            TextFormField(initialValue: r['name'] ?? '', decoration: InputDecoration(labelText: 'Full name'), onChanged: (v) => r['name'] = v),
            SizedBox(height:8),
            TextFormField(initialValue: r['email'] ?? '', decoration: InputDecoration(labelText: 'Email'), onChanged: (v) => r['email'] = v),
            SizedBox(height:8),
            TextFormField(initialValue: r['phone'] ?? '', decoration: InputDecoration(labelText: 'Phone'), onChanged: (v) => r['phone'] = v),
            SizedBox(height:8),
            TextFormField(initialValue: r['summary'] ?? '', decoration: InputDecoration(labelText: 'Professional summary'), maxLines: 4, onChanged: (v) => r['summary'] = v),
            SizedBox(height:6),
            Row(children: [
              ElevatedButton.icon(onPressed: _aiRewriteSummary, icon: Icon(Icons.auto_fix_high), label: Text('AI rewrite (offline)')),
              SizedBox(width:8),
              Text('(mock)'),
            ]),
            SizedBox(height:12),
            Text('Experience', style: TextStyle(fontWeight: FontWeight.bold)),
            ...List.generate((r['experience'] as List).length, (i) {
              final e = (r['experience'] as List)[i];
              return Card(margin: EdgeInsets.symmetric(vertical:6), child: Padding(padding: EdgeInsets.all(8), child: Column(children: [
                TextFormField(initialValue: e['role'], decoration: InputDecoration(labelText: 'Role / Title'), onChanged: (v) => e['role'] = v),
                TextFormField(initialValue: e['company'], decoration: InputDecoration(labelText: 'Company'), onChanged: (v) => e['company'] = v),
                TextFormField(initialValue: e['years'], decoration: InputDecoration(labelText: 'Years (e.g. 2020-2023)'), onChanged: (v) => e['years'] = v),
                TextFormField(initialValue: e['desc'], decoration: InputDecoration(labelText: 'Description / achievements'), maxLines: 3, onChanged: (v) => e['desc'] = v),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  if ((r['experience'] as List).length > 1)
                    TextButton(onPressed: () => _removeExperience(i), child: Text('Remove')),
                ])
              ])));
            }),
            Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: _addExperience, icon: Icon(Icons.add), label: Text('Add experience'))),
            SizedBox(height:8),
            Text('Education', style: TextStyle(fontWeight: FontWeight.bold)),
            ...List.generate((r['education'] as List).length, (i) {
              final e = (r['education'] as List)[i];
              return Card(margin: EdgeInsets.symmetric(vertical:6), child: Padding(padding: EdgeInsets.all(8), child: Column(children: [
                TextFormField(initialValue: e['degree'], decoration: InputDecoration(labelText: 'Degree / Qualification'), onChanged: (v) => e['degree'] = v),
                TextFormField(initialValue: e['school'], decoration: InputDecoration(labelText: 'School / University'), onChanged: (v) => e['school'] = v),
                TextFormField(initialValue: e['years'], decoration: InputDecoration(labelText: 'Years'), onChanged: (v) => e['years'] = v),
              ])));
            }),
            Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () { setState(() { (r['education'] as List).add({'school':'','degree':'','years':''}); }); }, icon: Icon(Icons.add), label: Text('Add education'))),
            SizedBox(height:8),
            TextFormField(initialValue: r['skills'] ?? '', decoration: InputDecoration(labelText: 'Skills (comma separated)'), onChanged: (v) => r['skills'] = v),
            SizedBox(height:16),
            ElevatedButton.icon(onPressed: _saveAndExit, icon: Icon(Icons.save), label: Text('Save resume')),
            SizedBox(height:12),
            Text('Template: ' + (r['template'] ?? 'ats_classic')),
            SizedBox(height:6),
            Text('Tip: Use "Admin" button on the Home screen to temporarily enable premium templates for testing.'),
            SizedBox(height:40),
          ]),
        ),
      ),
    );
  }
}
