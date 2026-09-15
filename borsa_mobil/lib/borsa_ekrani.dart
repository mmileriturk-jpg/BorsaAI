import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const BorsaApp());
}

class BorsaApp extends StatelessWidget {
  const BorsaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BorsaAI',
      theme: ThemeData.dark(),
      home: const FirsatlarSayfasi(),
    );
  }
}

class FirsatlarSayfasi extends StatefulWidget {
  const FirsatlarSayfasi({super.key});

  @override
  State<FirsatlarSayfasi> createState() => _FirsatlarSayfasiState();
}

class _FirsatlarSayfasiState extends State<FirsatlarSayfasi> {
  List<dynamic> firsatlar = [];
  bool yukleniyor = true;

  @override
  void initState() {
  super.initState();
    verileriCek();
  }

  Future<void> verileriCek() async {
    try {
      final yanit = await http.get(Uri.parse('http://127.0.0.1:8000/tara'));
      if (yanit.statusCode == 200) {
        setState(() {
          firsatlar = json.decode(yanit.body);
          yukleniyor = false;
        });
      }
    } catch (e) {
      setState(() {
        yukleniyor = false;
      });
      print("Bağlantı hatası: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BorsaAI Canlı Tarama'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() { yukleniyor = true; });
              verileriCek();
            },
          ),
        ],
      ),
      body: yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : firsatlar.isEmpty
              ? const Center(child: Text('Şu an eşleşen fırsat bulunamadı.'))
              : ListView.builder(
                  itemCount: firsatlar.length,
                  itemBuilder: (context, index) {
                    final item = firsatlar[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Text(item['hisse'][0]),
                        ),
                        title: Text(
                          item['hisse'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(item['detay']),
                        trailing: Text(
                          "${item['fiyat']} TL",
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}