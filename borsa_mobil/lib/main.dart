import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const BorsaAIApp());
}

class BorsaAIApp extends StatelessWidget {
  const BorsaAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BorsaAI Pro',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const AnaSayfa(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AnaSayfa extends StatefulWidget {
  const AnaSayfa({super.key});

  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  // Render Canlı Backend URL Adresi
  final String backendUrl = 'https://borsaai-41qx.onrender.com';
  
  List<dynamic> hisseler = [];
  bool isLoading = true;
  String mesaj = '';

  @override
  void initState() {
    super.initState();
    hisseleriGetir();
  }

  // Canlı sunucudan hisseleri çeken fonksiyon
  Future<void> hisseleriGetir() async {
    setState(() {
      isLoading = true;
      mesaj = '';
    });

    try {
      final response = await http.get(Uri.parse('$backendUrl/hisseler'));
      if (response.statusCode == 200) {
        setState(() {
          hisseler = jsonDecode(response.body);
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          mesaj = 'Sunucu hatası: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        mesaj = 'Bağlantı hatası: $e';
      });
    }
  }

  // Robotu çalıştıran POST isteği
  Future<void> robotuCalistir() async {
    try {
      final response = await http.post(Uri.parse('$backendUrl/robot-calistir'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'Robot başarıyla çalıştırıldı.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Robot çalıştırılamadı!'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BorsaAI Pro - Canlı BIST'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: hisseleriGetir,
            tooltip: 'Verileri Yenile',
          ),
        ],
      ),
      body: Column(
        children: [
          if (mesaj.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                mesaj,
                style: const TextStyle(color: Colors.redAccent, fontSize: 14),
              ),
            ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : hisseler.isEmpty
                    ? const Center(
                        child: Text(
                          'Hisse verisi bulunamadı.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    : ListView.builder(
                        itemCount: hisseler.length,
                        itemBuilder: (context, index) {
                          final hisse = hisseler[index];
                          return Card(
                            color: const Color(0xFF1E1E1E),
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blueAccent,
                                child: Text(
                                  hisse['kod'] ?? '',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12),
                                ),
                              ),
                              title: Text(
                                hisse['kod'] ?? '',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                'Fiyat: ₺${hisse['fiyat']}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              trailing: Chip(
                                label: Text(
                                  'RSI: ${hisse['rsi']}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                backgroundColor: Colors.teal.shade800,
                              ),
                            ),
                          );
                        },
                      ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: Colors.green.shade700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: robotuCalistir,
              icon: const Icon(Icons.play_arrow, color: Colors.white),
              label: const Text(
                'Robotu Çalıştır (POST)',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}