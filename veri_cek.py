import os
import ssl
import time
import urllib3
import requests
import yfinance as yf
import pandas as pd
import matplotlib.pyplot as plt
from datetime import datetime

# SSL ve güvenlik uyarılarını kapatalım
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
ssl._create_default_https_context = ssl._create_unverified_context

headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
}

session = requests.Session()
session.verify = False
session.headers.update(headers)

KLASOR_ADI = "grafikler"
if not os.path.exists(KLASOR_ADI):
    os.makedirs(KLASOR_ADI)

temel_tickers = {
    "Bitcoin": "BTC-USD",
    "Ethereum": "ETH-USD",
    "Dogecoin": "DOGE-USD",
    "Türk Hava Yolları": "THYAO.IS",
    "Tüpraş (BIST)": "TUPRS.IS",
    "BİM (BIST)": "BIMAS.IS",
    "Astor Enerji": "ASTOR.IS",
    "Microsoft": "MSFT",
    "Apple": "AAPL",
    "Ons Altın": "GC=F"
}

taranacak_havuz = {
    "Solana": "SOL-USD",
    "Avalanche": "AVAX-USD",
    "Akbank": "AKBNK.IS",
    "İş Bankası (C)": "ISCTR.IS",
    "Ereğli Demir Çelik": "EREGL.IS",
    "Sasa Polyester": "SASA.IS",
    "Nvidia": "NVDA",
    "Tesla": "TSLA"
}

positive_words = ['surge', 'jump', 'rise', 'gain', 'bull', 'growth', 'profit', 'high', 'up', 'beat', 'positive', 'strong']
negative_words = ['drop', 'fall', 'plunge', 'loss', 'bear', 'crash', 'low', 'down', 'miss', 'negative', 'weak', 'risk']

def analyze_sentiment(news_list):
    if not news_list:
        return "Nötr"
    pos_count = sum(1 for n in news_list if any(w in n.get('title', '').lower() for w in positive_words))
    neg_count = sum(1 for n in news_list if any(w in n.get('title', '').lower() for w in negative_words))
    
    if pos_count > neg_count:
        return "Pozitif"
    elif neg_count > pos_count:
        return "Negatif"
    else:
        return "Nötr"

CUZDAN_DOSYASI = "cuzdan_durumu.csv"
POZISYON_DOSYASI = "acik_pozisyonlar.csv"
BASLANGIC_NAKIT = 100000.0
ISLEM_TUTARI = 10000.0

def portföy_nakit_oku():
    if os.path.exists(CUZDAN_DOSYASI):
        try:
            df_cuzdan = pd.read_csv(CUZDAN_DOSYASI)
            return float(df_cuzdan.iloc[-1]['Kalan Nakit'])
        except:
            pass
    return BASLANGIC_NAKIT

def acik_pozisyonlari_oku():
    if os.path.exists(POZISYON_DOSYASI):
        try:
            return pd.read_csv(POZISYON_DOSYASI)
        except:
            pass
    return pd.DataFrame(columns=["Varlik", "Sembol", "AlisFiyati", "Adet", "StopLoss", "KarAl"])

def otomatik_piyasa_taramasi_ve_yonetim():
    print("=== OTO-PİLOT: PİYASA TARAMASI VE STOP/KÂR KONTROLÜ BAŞLATILDI ===")
    
    aktif_tickers = temel_tickers.copy()
    for name, symbol in taranacak_havuz.items():
        try:
            t = yf.Ticker(symbol, session=session)
            df_test = t.history(period="5d")
            if not df_test.empty:
                aktif_tickers[name] = symbol
        except:
            pass

    nakit_bakiye = portföy_nakit_oku()
    df_pozisyonlar = acik_pozisyonlari_oku()
    simdi = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    arsiv_listesi = []
    alarm_mesajlari = []
    yeni_pozisyonlar = []

    # 1. Açık Pozisyonları Kontrol Et (Stop-Loss / Take-Profit Otomasyonu)
    guncel_acik_pozisyonlar = []
    if not df_pozisyonlar.empty:
        print("[OTO] Açık pozisyonlar stop-loss ve kâr al seviyelerine göre kontrol ediliyor...")
        for index, pos in df_pozisyonlar.iterrows():
            varlik = pos['Varlik']
            sembol = pos['Sembol']
            alis_fiyati = float(pos['AlisFiyati'])
            adet = float(pos['Adet'])
            stop_loss = float(pos['StopLoss'])
            kar_al = float(pos['KarAl'])
            
            try:
                t_anlik = yf.Ticker(sembol, session=session)
                df_anlik = t_anlik.history(period="1d")
                anlik_fiyat = float(df_anlik['Close'].iloc[-1]) if not df_anlik.empty else alis_fiyati
            except:
                anlik_fiyat = alis_fiyati

            if anlik_fiyat <= stop_loss:
                satis_tutari = adet * anlik_fiyat
                nakit_bakiye += satis_tutari
                zarar = (anlik_fiyat - alis_fiyati) * adet
                print(f"  -> [STOP-LOSS] {varlik} zararla kapatıldı! Tutar: {satis_tutari:,.2f} TL (Zarar: {zarar:,.2f} TL)")
            elif anlik_fiyat >= kar_al:
                satis_tutari = adet * anlik_fiyat
                nakit_bakiye += satis_tutari
                kar = (anlik_fiyat - alis_fiyati) * adet
                print(f"  -> [KÂR AL] {varlik} kârla kapatıldı! Tutar: {satis_tutari:,.2f} TL (Kâr: {kar:,.2f} TL)")
            else:
                guncel_acik_pozisyonlar.append(pos.to_dict())

        df_pozisyonlar = pd.DataFrame(guncel_acik_pozisyonlar)

    # 2. Piyasa Taraması ve Otomatik Alım Sinyalleri
    for name, symbol in aktif_tickers.items():
        try:
            t = yf.Ticker(symbol, session=session)
            df = t.history(period="30d")
            if df.empty:
                df = t.history(period="5d")
                
            if not df.empty:
                son_fiyat = float(df['Close'].iloc[-1])
                pencere = min(20, len(df))
                sma_val = float(df['Close'].rolling(window=pencere).mean().iloc[-1]) if len(df) >= 5 else son_fiyat
                
                trend = "YÜKSELİŞ" if son_fiyat > sma_val else "DÜŞÜŞ/YATAY"
                stop_loss_fiyati = son_fiyat * 0.95
                kar_al_fiyati = son_fiyat * 1.10
                
                # Grafik Kaydet
                plt.figure(figsize=(9, 4))
                plt.plot(df.index, cz := df['Close'], label='Kapanış Fiyatı', color='blue', marker='o', linewidth=1.5)
                if len(df) >= 5:
                    sma_seri = cz.rolling(window=pencere).mean()
                    plt.plot(df.index, sma_seri, label='SMA', color='orange', linestyle='--', linewidth=1.5)
                plt.axhline(y=stop_loss_fiyati, color='red', linestyle=':', label=f'Stop: {stop_loss_fiyati:.2f}')
                plt.axhline(y=kar_al_fiyati, color='green', linestyle=':', label=f'KârAl: {kar_al_fiyati:.2f}')
                plt.title(f"{name} ({symbol}) - Fiyat & Risk", fontsize=11, fontweight='bold')
                plt.legend(loc='best', fontsize=8)
                plt.grid(True, linestyle=':', alpha=0.6)
                plt.tight_layout()
                
                temiz_isim = symbol.replace("=", "_").replace(".", "_").replace("-", "_")
                plt.savefig(os.path.join(KLASOR_ADI, f"{temiz_isim}_grafik.png"))
                plt.close()
            else:
                son_fiyat = 0.0
                stop_loss_fiyati = 0.0
                kar_al_fiyati = 0.0
                trend = "VERİ ALINAMADI"

            try:
                news_data = t.news
            except:
                news_data = []
            sentiment = analyze_sentiment(news_data)
            
            islem_durumu = "BEKLEMEDE"
            tavsiye = "İZLE"
            
            if trend == "YÜKSELİŞ" and sentiment in ["Pozitif", "Nötr"]:
                tavsiye = "AL / TUT"
                zaten_elde_var = False
                if not df_pozisyonlar.empty and symbol in df_pozisyonlar['Sembol'].values:
                    zaten_elde_var = True
                    
                if not zaten_elde_var and nakit_bakiye >= ISLEM_TUTARI:
                    nakit_bakiye -= ISLEM_TUTARI
                    adet = ISLEM_TUTARI / son_fiyat
                    islem_durumu = f"OTO-ALIM YAPILDI ({ISLEM_TUTARI} TL)"
                    yeni_pozisyonlar.append({
                        "Varlik": name,
                        "Sembol": symbol,
                        "AlisFiyati": son_fiyat,
                        "Adet": adet,
                        "StopLoss": stop_loss_fiyati,
                        "KarAl": kar_al_fiyati
                    })
                elif zaten_elde_var:
                    islem_durumu = "ZATEN PORTFÖYDE VAR"
            elif trend == "DÜŞÜŞ/YATAY":
                tavsiye = "DİKKAT / RİSK"
                islem_durumu = "DÜŞÜŞ TRENDİ"

            arsiv_listesi.append({
                "Zaman": simdi,
                "Varlik": name,
                "Sembol": symbol,
                "Fiyat": round(float(son_fiyat), 4),
                "StopLoss": round(float(stop_loss_fiyati), 4),
                "KarAl": round(float(kar_al_fiyati), 4),
                "Trend": trend,
                "Tavsiye": tavsiye,
                "Islem": islem_durumu,
                "Duygu": sentiment
            })

            if "DÜŞÜŞ" in trend:
                alarm_mesajlari.append(f"[{simdi}] ALARM: {name} ({symbol}) düşüşte! Stop Seviyesi: {stop_loss_fiyati:.4f}\n")

        except Exception as e:
            pass
        
        time.sleep(0.3)

    # Dosya Güncellemeleri
    if yeni_pozisyonlar:
        df_yeni = pd.DataFrame(yeni_pozisyonlar)
        df_pozisyonlar = pd.concat([df_pozisyonlar, df_yeni], ignore_index=True) if not df_pozisyonlar.empty else df_yeni

    df_pozisyonlar.to_csv(POZISYON_DOSYASI, index=False, encoding='utf-8-sig')

    df_arsiv = pd.DataFrame(arsiv_listesi)
    dosya_var = os.path.exists("piyasa_arsivi.csv")
    df_arsiv.to_csv("piyasa_arsivi.csv", mode='a', index=False, header=not dosya_var, encoding='utf-8-sig')

    cuzdan_ozeti = pd.DataFrame([{
        "Zaman": simdi,
        "Kalan Nakit": round(nakit_bakiye, 2),
        "Aktif Pozisyon Sayisi": len(df_pozisyonlar)
    }])
    cuzdan_ozeti.to_csv(CUZDAN_DOSYASI, mode='a', index=False, header=not os.path.exists(CUZDAN_DOSYASI), encoding='utf-8-sig')

    if alarm_mesajlari:
        with open("alarm_log.txt", "a", encoding="utf-8") as log_dosyasi:
            log_dosyasi.writelines(alarm_mesajlari)

    print("[OTO-PİLOT TAMAMLANDI] Arka plan taraması, stop kontrolleri ve kayıtlar güncellendi.\n")


# --- İNTERAKTİF KULLANICI İŞLEM MENÜSÜ ---
def interaktif_menu():
    while True:
        nakit = portföy_nakit_oku()
        pozisyonlar = acik_pozisyonlari_oku()
        
        print("==========================================")
        print("       BORSA AI - İŞLEM TERMİNALİ         ")
        print("==========================================")
        print(f"💰 Kalan Sanal Nakit    : {nakit:,.2f} TL")
        print(f"📦 Açık Pozisyon Sayısı : {len(pozisyonlar)}")
        print("------------------------------------------")
        print("1. Portföyümü ve Açık Pozisyonları Listele")
        print("2. Manuel Sanal Alım Yap")
        print("3. Pozisyon Kapat / Satış Yap")
        print("4. Çıkış Yap")
        print("==========================================")
        
        secim = input("Lütfen bir işlem seçin (1-4): ").strip()
        
        if secim == "1":
            print("\n--- AÇIK POZİSYONLARINIZ ---")
            if pozisyonlar.empty:
                print("Henüz açık bir pozisyonunuz bulunmuyor.")
            else:
                for idx, row in pozisyonlar.iterrows():
                    print(f"[{idx}] Varlık: {row['Varlik']} ({row['Sembol']}) | Alış Fiyatı: {row['AlisFiyati']:.4f} | Adet: {row['Adet']:.2f} | Stop: {row['StopLoss']:.2f}")
            print("\n")
            
        elif secim == "2":
            print("\n--- MANUEL ALIM YAPILABİLİR VARLIKLAR ---")
            tum_liste = {**temel_tickers, **taranacak_havuz}
            keys = list(tum_liste.keys())
            for i, name in enumerate(keys):
                print(f"[{i+1}] {name} ({tum_liste[name]})")
            
            try:
                secim_idx = int(input("Almak istediğiniz varlığın numarasını girin: ")) - 1
                if 0 <= secim_idx < len(keys):
                    secilen_isim = keys[secim_idx]
                    secilen_sembol = tum_liste[secilen_isim]
                    
                    t_anlik = yf.Ticker(secilen_sembol, session=session)
                    df_anlik = t_anlik.history(period="1d")
                    if df_anlik.empty:
                        print("[HATA] Bu varlığa ait anlık fiyat verisi bulunamadı.")
                        continue
                    
                    anlik_fiyat = float(df_anlik['Close'].iloc[-1])
                    tutar = float(input(f"Yatırmak istediğiniz tutar (TL) [Mevcut Nakit: {nakit:,.2f}]: "))
                    
                    if tutar > nakit:
                        print("[HATA] Yetersiz bakiye!")
                    elif tutar <= 0:
                        print("[HATA] Geçersiz tutar!")
                    else:
                        nakit -= tutar
                        adet = tutar / anlik_fiyat
                        stop_loss = anlik_fiyat * 0.95
                        kar_al = anlik_fiyat * 1.10
                        
                        yeni_satir = pd.DataFrame([{
                            "Varlik": secilen_isim,
                            "Sembol": secilen_sembol,
                            "AlisFiyati": anlik_fiyat,
                            "Adet": adet,
                            "StopLoss": stop_loss,
                            "KarAl": kar_al
                        }])
                        
                        if not pozisyonlar.empty:
                            pozisyonlar = pd.concat([pozisyonlar, yeni_satir], ignore_index=True)
                        else:
                            pozisyonlar = yeni_satir
                            
                        pozisyonlar.to_csv(POZISYON_DOSYASI, index=False, encoding='utf-8-sig')
                        
                        simdi = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                        cuzdan_ozeti = pd.DataFrame([{
                            "Zaman": simdi,
                            "Kalan Nakit": round(nakit, 2),
                            "Aktif Pozisyon Sayisi": len(pozisyonlar)
                        }])
                        cuzdan_ozeti.to_csv(CUZDAN_DOSYASI, mode='a', index=False, header=not os.path.exists(CUZDAN_DOSYASI), encoding='utf-8-sig')
                        
                        print(f"[BAŞARILI] {secilen_isim} varlığından {tutar:,.2f} TL'lik manuel alım yapıldı!\n")
                else:
                    print("[HATA] Geçersiz seçim.")
            except Exception as e:
                print(f"[HATA] İşlem başarısız: {e}\n")
                
        elif secim == "3":
            print("\n--- POZİSYON KAPAT / SATIŞ YAP ---")
            if pozisyonlar.empty:
                print("Kapatılacak açık pozisyonunuz yok.")
            else:
                for idx, row in pozisyonlar.iterrows():
                    print(f"[{idx}] {row['Varlik']} ({row['Sembol']}) - Alış: {row['AlisFiyati']:.4f}")
                try:
                    kapat_idx = int(input("Kapatmak istediğiniz pozisyonun numarasını girin: "))
                    if 0 <= kapat_idx < len(pozisyonlar):
                        satilacak = pozisyonlar.iloc[kapat_idx]
                        t_anlik = yf.Ticker(satilacak['Sembol'], session=session)
                        df_anlik = t_anlik.history(period="1d")
                        anlik_fiyat = float(df_anlik['Close'].iloc[-1]) if not df_anlik.empty else float(satilacak['AlisFiyati'])
                        
                        satis_geliri = float(satilacak['Adet']) * anlik_fiyat
                        nakit += satis_geliri
                        
                        pozisyonlar = pozisyonlar.drop(kapat_idx).reset_index(drop=True)
                        pozisyonlar.to_csv(POZISYON_DOSYASI, index=False, encoding='utf-8-sig')
                        
                        simdi = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                        cuzdan_ozeti = pd.DataFrame([{
                            "Zaman": simdi,
                            "Kalan Nakit": round(nakit, 2),
                            "Aktif Pozisyon Sayisi": len(pozisyonlar)
                        }])
                        cuzdan_ozeti.to_csv(CUZDAN_DOSYASI, mode='a', index=False, header=not os.path.exists(CUZDAN_DOSYASI), encoding='utf-8-sig')
                        
                        print(f"[BAŞARILI] {satilacak['Varlik']} pozisyonu kapatıldı. Cüzdana {satis_geliri:,.2f} TL eklendi.\n")
                    else:
                        print("[HATA] Geçersiz pozisyon numarası.")
                except Exception as e:
                    print(f"[HATA] Satış işlemi başarısız: {e}\n")
                    
        elif secim == "4":
            print("Terminalden çıkılıyor. Görüşmek üzere!")
            break
        else:
            print("[UYARI] Lütfen 1 ile 4 arasında geçerli bir seçim yapın.\n")


if __name__ == "__main__":
    # 1. Önce arka planda otomatik taramayı ve stop-loss/take-profit kontrollerini çalıştır
    otomatik_piyasa_taramasi_ve_yonetim()
    
    # 2. Ardından interaktif işlem menüsünü aç
    interaktif_menu()