import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class BorsaEkrani extends StatefulWidget {
  final Function(String, double, int) onIslem;
  final String hisseAdi;
  final double guncelFiyat;

  const BorsaEkrani({
    Key? key,
    required this.onIslem,
    required this.hisseAdi,
    required this.guncelFiyat,
  }) : super(key: key);

  @override
  State<BorsaEkrani> createState() => _BorsaEkraniState();
}

class _BorsaEkraniState extends State<BorsaEkrani> {
  final TextEditingController _adetController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _apiData;

  @override
  void initState() {
    super.initState();
    _verileriGetir();
  }

  // Canlı Render bulut sunucumuzdan veri çeken fonksiyon
  Future<void> _verileriGetir() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Yerel IP yerine Render bulut adresimiz kullanılıyor
      final response = await http.get(
        Uri.parse('https://borsaai-41qx.onrender.com/hisse/${widget.hisseAdi}'),
      );

      if (response.statusCode == 200) {
        setState(() {
          _apiData = jsonDecode(response.body);
        });
      }
    } catch (e) {
      debugPrint("Bağlantı hatası: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "${widget.hisseAdi} İşlem Paneli",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            "Güncel Fiyat: ${widget.guncelFiyat} TL",
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _adetController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Adet Giriniz',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: () {
                  int adet = int.tryParse(_adetController.text) ?? 0;
                  if (adet > 0) {
                    widget.onIslem(widget.hisseAdi, widget.guncelFiyat, adet);
                    Navigator.pop(context);
                  }
                },
                child: const Text('SAT', style: TextStyle(color: Colors.red, fontSize: 16)),
              ),
              ElevatedButton(
                onPressed: () {
                  int adet = int.tryParse(_adetController.text) ?? 0;
                  if (adet > 0) {
                    widget.onIslem(widget.hisseAdi, widget.guncelFiyat, adet);
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                child: const Text('AL', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}