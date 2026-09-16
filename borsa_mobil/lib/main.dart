import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

void main() {
  runApp(const BorsaApp());
}

class BorsaApp extends StatelessWidget {
  const BorsaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BorsaAI Pro - Algo-Trading',
      theme: ThemeData.dark(),
      home: const AnaSayfa(),
    );
  }
}

class PortfoyItem {
  final String hisse;
  int adet;
  double maliyet;

  PortfoyItem({required this.hisse, required this.adet, required this.maliyet});
}

class AnaSayfa extends StatefulWidget {
  const AnaSayfa({super.key});

  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  int _seciliSayfa = 0;
  List<dynamic> tumFirsatlar = [];
  List<dynamic> filtrelenmisFirsatlar = [];
  List<String> favoriler = [];
  List<PortfoyItem> portfoy = [
    PortfoyItem(hisse: 'ASELS', adet: 100, maliyet: 180.0),
    PortfoyItem(hisse: 'THYAO', adet: 50, maliyet: 270.0),
  ];
  double nakitBakiye = 50000.0;
  bool yukleniyor = true;
  String aramaMetni = "";
  String siralamaKriteri = "varsayilan";
  final TextEditingController _aramaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    verileriCek();
  }

  String getApiUrl(String endpoint) {
    const port = "8000";
    if (kIsWeb) {
      return 'http://127.0.0.1:$port$endpoint';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:$port$endpoint';
    } else {
      return 'http://127.0.0.1:$port$endpoint';
    }
  }

  Future<void> verileriCek() async {
    setState(() => yukleniyor = true);
    try {
      final yanit = await http.get(Uri.parse(getApiUrl('/tara')));
      if (yanit.statusCode == 200) {
        final gelenVeri = json.decode(yanit.body);
        setState(() {
          tumFirsatlar = gelenVeri;
          filtreleVeSirala(aramaMetni, siralamaKriteri);
          yukleniyor = false;
        });
      } else {
        setState(() => yukleniyor = false);
      }
    } catch (e) {
      setState(() => yukleniyor = false);
      print("Bağlantı hatası: $e");
    }
  }

  Future<void> robotuCalistir() async {
    try {
      final yanit = await http.post(Uri.parse(getApiUrl('/otomatik_islem_calistir')));
      if (yanit.statusCode == 200) {
        final sonuc = json.decode(yanit.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Robot Çalıştı: ${sonuc['yapilan_islem_sayisi']} işlem yapıldı.")),
        );
        verileriCek();
      }
    } catch (e) {
      print("Robot hatası: $e");
    }
  }

  void filtreleVeSirala(String aranan, String kriter) {
    setState(() {
      aramaMetni = aranan;
      siralamaKriteri = kriter;

      if (aranan.isEmpty) {
        filtrelenmisFirsatlar = List.from(tumFirsatlar);
      } else {
        filtrelenmisFirsatlar = tumFirsatlar.where((item) {
          final hisseAdi = item['hisse']?.toString().toLowerCase() ?? '';
          return hisseAdi.contains(aranan.toLowerCase());
        }).toList();
      }

      if (siralamaKriteri == "fiyat_artan") {
        filtrelenmisFirsatlar.sort((a, b) => (a['fiyat'] ?? 0.0).compareTo(b['fiyat'] ?? 0.0));
      } else if (siralamaKriteri == "fiyat_azalan") {
        filtrelenmisFirsatlar.sort((a, b) => (b['fiyat'] ?? 0.0).compareTo(a['fiyat'] ?? 0.0));
      } else if (siralamaKriteri == "degisim_azalan") {
        filtrelenmisFirsatlar.sort((a, b) => (b['degisim'] ?? 0.0).compareTo(a['degisim'] ?? 0.0));
      }
    });
  }

  void favoriDegistir(String hisse) {
    setState(() {
      if (favoriler.contains(hisse)) {
        favoriler.remove(hisse);
      } else {
        favoriler.add(hisse);
      }
    });
  }

  double guncelFiyatGetir(String hisseAdi) {
    final bulunan = tumFirsatlar.firstWhere(
      (item) => item['hisse'] == hisseAdi,
      orElse: () => {'fiyat': 0.0},
    );
    return (bulunan['fiyat'] ?? 0.0).toDouble();
  }

  void islemYap(String hisseAdi, double fiyat, int adet, bool aliyorMu) {
    setState(() {
      double toplamTutar = fiyat * adet;

      if (aliyorMu) {
        if (nakitBakiye < toplamTutar) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Yetersiz nakit bakiye!")),
          );
          return;
        }
        nakitBakiye -= toplamTutar;
        var mevcutPortfoy = portfoy.where((p) => p.hisse == hisseAdi).toList();
        if (mevcutPortfoy.isNotEmpty) {
          var p = mevcutPortfoy.first;
          double toplamMaliyetTutar = (p.adet * p.maliyet) + toplamTutar;
          p.adet += adet;
          p.maliyet = toplamMaliyetTutar / p.adet;
        } else {
          portfoy.add(PortfoyItem(hisse: hisseAdi, adet: adet, maliyet: fiyat));
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$adet adet $hisseAdi başarıyla alındı.")),
        );
      } else {
        var mevcutPortfoy = portfoy.where((p) => p.hisse == hisseAdi).toList();
        if (mevcutPortfoy.isEmpty || mevcutPortfoy.first.adet < adet) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Portföyde bu kadar adet hisse yok!")),
          );
          return;
        }
        var p = mevcutPortfoy.first;
        nakitBakiye += toplamTutar;
        p.adet -= adet;
        if (p.adet == 0) {
          portfoy.removeWhere((item) => item.hisse == hisseAdi);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$adet adet $hisseAdi başarıyla satıldı.")),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sayfalar = [
      _firsatlarSekmesi(),
      _favorilerSekmesi(),
      _portfoySekmesi(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('BorsaAI Pro - Algo-Trading'),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: robotuCalistir,
            icon: const Icon(Icons.smart_toy, color: Colors.white),
            label: const Text('Robot', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.refresh), onPressed: verileriCek),
          const SizedBox(width: 8),
        ],
      ),
      body: sayfalar[_seciliSayfa],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _seciliSayfa,
        onTap: (index) => setState(() => _seciliSayfa = index),
        selectedItemColor: Colors.tealAccent,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.trending_up), label: 'Fırsatlar'),
          BottomNavigationBarItem(icon: Icon(Icons.star), label: 'Favoriler'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Portföy & Al-Sat'),
        ],
      ),
    );
  }

  Widget _firsatlarSekmesi() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _aramaController,
                  onChanged: (val) => filtreleVeSirala(val, siralamaKriteri),
                  decoration: InputDecoration(
                    hintText: 'Hisse ara...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: siralamaKriteri,
                    dropdownColor: Colors.grey[900],
                    items: const [
                      DropdownMenuItem(value: 'varsayilan', child: Text('Sıralama')),
                      DropdownMenuItem(value: 'fiyat_artan', child: Text('Fiyat Artan')),
                      DropdownMenuItem(value: 'fiyat_azalan', child: Text('Fiyat Azalan')),
                      DropdownMenuItem(value: 'degisim_azalan', child: Text('En Çok Artan')),
                    ],
                    onChanged: (val) {
                      if (val != null) filtreleVeSirala(aramaMetni, val);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: yukleniyor
              ? const Center(child: CircularProgressIndicator())
              : filtrelenmisFirsatlar.isEmpty
                  ? const Center(child: Text('Kriterlere uygun hisse bulunamadı.'))
                  : ListView.builder(
                      itemCount: filtrelenmisFirsatlar.length,
                      itemBuilder: (context, index) {
                        final item = filtrelenmisFirsatlar[index];
                        final hisseAdi = item['hisse'] ?? '';
                        final favorideMi = favoriler.contains(hisseAdi);

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.teal,
                              child: Text(hisseAdi.isNotEmpty ? hisseAdi[0] : '?'),
                            ),
                            title: Row(
                              children: [
                                Text(hisseAdi, style: const TextStyle(fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon: Icon(
                                    favorideMi ? Icons.star : Icons.star_border,
                                    color: favorideMi ? Colors.amber : Colors.grey,
                                  ),
                                  onPressed: () => favoriDegistir(hisseAdi),
                                ),
                              ],
                            ),
                            subtitle: Text(item['detay'] ?? ''),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "${item['fiyat']} TL",
                                  style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text(
                                  "%${item['degisim']}",
                                  style: TextStyle(
                                    color: (item['degisim'] ?? 0) >= 0 ? Colors.green : Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => HisseDetaySayfasi(
                                    item: item,
                                    onIslemYap: islemYap,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _favorilerSekmesi() {
    final favoriListesi = tumFirsatlar.where((item) => favoriler.contains(item['hisse'])).toList();

    if (favoriListesi.isEmpty) {
      return const Center(child: Text('Henüz favoriye eklenen hisse yok.', style: TextStyle(fontSize: 16, color: Colors.grey)));
    }

    return ListView.builder(
      itemCount: favoriListesi.length,
      itemBuilder: (context, index) {
        final item = favoriListesi[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: Colors.amber, child: Text(item['hisse'][0])),
            title: Text(item['hisse'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(item['detay'] ?? ''),
            trailing: Text("${item['fiyat']} TL", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HisseDetaySayfasi(item: item, onIslemYap: islemYap),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _portfoySekmesi() {
    double toplamHisseDegeri = 0;
    double toplamMaliyet = 0;

    for (var p in portfoy) {
      double guncelFiyat = guncelFiyatGetir(p.hisse);
      toplamHisseDegeri += p.adet * guncelFiyat;
      toplamMaliyet += p.adet * p.maliyet;
    }

    double toplamVarlik = toplamHisseDegeri + nakitBakiye;
    double toplamKarZarar = toplamHisseDegeri - toplamMaliyet;
    double toplamKarZararYuzde = toplamMaliyet > 0 ? (toplamKarZarar / toplamMaliyet) * 100 : 0;

    double nakitOran = toplamVarlik > 0 ? nakitBakiye / toplamVarlik : 0;
    double hisseOran = toplamVarlik > 0 ? toplamHisseDegeri / toplamVarlik : 0;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            color: Colors.grey[900],
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Varlık & Portföy Özeti", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Toplam Varlık:"),
                      Text("${toplamVarlik.toStringAsFixed(2)} TL", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.tealAccent, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Hisse Değeri:"),
                      Text("${toplamHisseDegeri.toStringAsFixed(2)} TL"),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Nakit Bakiye:"),
                      Text("${nakitBakiye.toStringAsFixed(2)} TL", style: const TextStyle(color: Colors.amberAccent)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Kar / Zarar:"),
                      Text(
                        "${toplamKarZarar >= 0 ? '+' : ''}${toplamKarZarar.toStringAsFixed(2)} TL (%${toplamKarZararYuzde.toStringAsFixed(2)})",
                        style: TextStyle(
                          color: toplamKarZarar >= 0 ? Colors.greenAccent : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text("Portföy Dağılım Grafiği", style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 6),
                  // Görsel Dağılım Çubuğu (Grafik)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 16,
                      child: Row(
                        children: [
                          Expanded(
                            flex: (hisseOran * 100).toInt().clamp(1, 100),
                            child: Container(color: Colors.tealAccent),
                          ),
                          Expanded(
                            flex: (nakitOran * 100).toInt().clamp(1, 100),
                            child: Container(color: Colors.amberAccent),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Hisse: %${(hisseOran * 100).toStringAsFixed(1)}", style: const TextStyle(fontSize: 11, color: Colors.tealAccent)),
                      Text("Nakit: %${(nakitOran * 100).toStringAsFixed(1)}", style: const TextStyle(fontSize: 11, color: Colors.amberAccent)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text("Portföyüm & Al-Sat", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: portfoy.length,
              itemBuilder: (context, index) {
                final p = portfoy[index];
                double guncelFiyat = guncelFiyatGetir(p.hisse);
                double varlikDegeri = p.adet * guncelFiyat;
                double karZarar = varlikDegeri - (p.adet * p.maliyet);

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text("${p.hisse} (${p.adet} Adet)", style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("Maliyet: ${p.maliyet} | Güncel: $guncelFiyat"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "${karZarar >= 0 ? '+' : ''}${karZarar.toStringAsFixed(2)} TL",
                          style: TextStyle(color: karZarar >= 0 ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.swap_horiz, color: Colors.tealAccent),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => IslemDialog(
                                hisseAdi: p.hisse,
                                guncelFiyat: guncelFiyat,
                                onIslem: islemYap,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class HisseDetaySayfasi extends StatelessWidget {
  final dynamic item;
  final Function(String, double, int, bool) onIslemYap;

  const HisseDetaySayfasi({super.key, required this.item, required this.onIslemYap});

  @override
  Widget build(BuildContext context) {
    List<dynamic> gecmisFiyatlar = item['gecmis_fiyatlar'] ?? [];
    double fiyat = (item['fiyat'] ?? 0.0).toDouble();
    String hisseAdi = item['hisse'] ?? '';

    return Scaffold(
      appBar: AppBar(title: Text("$hisseAdi Detay & Al-Sat")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Hisse: $hisseAdi", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("Fiyat: $fiyat TL", style: const TextStyle(fontSize: 18, color: Colors.greenAccent)),
            const SizedBox(height: 8),
            Text("Strateji: ${item['detay'] ?? ''}", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text("RSI Değeri: ${item['rsi']}", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => IslemDialog(
                      hisseAdi: hisseAdi,
                      guncelFiyat: fiyat,
                      onIslem: onIslemYap,
                    ),
                  );
                },
                child: const Text('Hisse Al / Sat', style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),
            const Text("Simüle Edilmiş Geçmiş Fiyatlar:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: gecmisFiyatlar.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    dense: true,
                    title: Text("Periyot ${index + 1}"),
                    trailing: Text("${gecmisFiyatlar[index]} TL", style: const TextStyle(fontWeight: FontWeight.bold)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class IslemDialog extends StatefulWidget {
  final String hisseAdi;
  final double guncelFiyat;
  final Function(String, double, int, bool) onIslem;

  const IslemDialog({super.key, required this.hisseAdi, required this.guncelFiyat, required this.onIslem});

  @override
  State<IslemDialog> createState() => _IslemDialogState();
}

class _IslemDialogState extends State<IslemDialog> {
  final TextEditingController _adetController = TextEditingController(text: '10');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("${widget.hisseAdi} İşlem Yap"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Güncel Fiyat: ${widget.guncelFiyat} TL"),
          const SizedBox(height: 12),
          TextField(
            controller: _adetController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Adet Miktarı', border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            int adet = int.tryParse(_adetController.text) ?? 0;
            if (adet > 0) {
              widget.onIslem(widget.hisseAdi, widget.guncelFiyat, adet, false);
              Navigator.pop(context);
            }
          },
          child: const Text('SAT', style: TextStyle(color: Colors.redAccent)),
        ),
        ElevatedButton(
          onPressed: () {
            int adet = int.tryParse(_adetController.text) ?? 0;
            if (adet > 0) {
              widget.onIslem(widget.hisseAdi, widget.guncelFiyat, adet, true);
              Navigator.pop(context);
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: const Text('AL', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}