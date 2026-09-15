import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const BorsaAIApp());
}

class BorsaAIApp extends StatelessWidget {
  const BorsaAIApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BorsaAI Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFF00E676),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E676),
          secondary: Color(0xFF00E676),
        ),
      ),
      home: const AnaSayfa(),
    );
  }
}

class AnaSayfa extends StatefulWidget {
  const AnaSayfa({Key? key}) : super(key: key);

  @override
  _AnaSayfaState createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  final String backendUrl = 'https://borsaai-41qx.onrender.com';
  List<dynamic> hisseler = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    hisseleriGetir();
  }

  Future<void> hisseleriGetir() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final response = await http.get(Uri.parse('$backendUrl/hisseler'));
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          if (data is List) {
            hisseler = data;
          } else if (data is Map && data.containsKey('hisseler')) {
            hisseler = data['hisseler'];
          } else {
            hisseler = [];
          }
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Sunucu hatası: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Bağlantı kurulamadı. İnternetinizi veya sunucuyu kontrol edin.';
        isLoading = false;
      });
    }
  }

  Future<void> robotuTetikle() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Robot işlem tetikleniyor, sunucuya bağlanılıyor...')),
      );

      final response = await http.post(Uri.parse('$backendUrl/robot-calistir'));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String detays = data['detay'] ?? 'Emirler iletildi.';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Başarılı: $detays'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sunucu yanıt verdi ancak işlem başarısız (${response.statusCode}).'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Robota ulaşılamadı, ağ bağlantınızı kontrol edin.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BorsaAI Pro - Algo-Trading'),
        backgroundColor: const Color(0xFF1E1E1E),
        actions: [
          IconButton(
            icon: const Icon(Icons.smart_toy, color: Color(0xFF00E676)),
            tooltip: 'Robotu Çalıştır',
            onPressed: robotuTetikle,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
            onPressed: hisseleriGetir,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
          : errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00E676),
                            foregroundColor: Colors.black,
                          ),
                          onPressed: hisseleriGetir,
                          child: const Text('Tekrar Dene'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: hisseler.length,
                  itemBuilder: (context, index) {
                    final hisse = hisseler[index];
                    final double degisim = (hisse['degisim'] ?? 0.0).toDouble();
                    final double rsi = (hisse['rsi'] ?? 50.0).toDouble();
                    final String detay = hisse['detay'] ?? '';

                    return Card(
                      color: const Color(0xFF1E1E1E),
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ListTile(
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                hisse['sembol'] ?? 'Bilinmiyor',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
                              ),
                              Text(
                                '${hisse['fiyat']} TL',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent, fontSize: 16),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                              Text('RSI: $rsi | Durum: $detay', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Text('Değişim: ', style: TextStyle(color: Colors.grey)),
                                  Text(
                                    '${degisim >= 0 ? '+' : ''}$degisim%',
                                    style: TextStyle(
                                      color: degisim >= 0 ? Colors.greenAccent : Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00E676),
                              foregroundColor: Colors.black,
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${hisse['sembol']} için manuel işlem tetiklendi.')),
                              );
                            },
                            child: const Text('İşlem Yap'),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}