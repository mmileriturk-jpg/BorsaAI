from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import yfinance as yf
import pandas as pd
import numpy as np
from datetime import datetime

app = FastAPI(title="BorsaAI Pro API", version="2.0.0")

# Flutter Web / Mobil bağlantıları için CORS ayarları
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Takip edilen popüler BIST hisseleri (Yahoo Finance uzantısı '.IS' ile)
HIZMET_LISTESI = [
    "ASELS.IS", "THYAO.IS", "EREGL.IS", "GARAN.IS", 
    "KCHOL.IS", "SISE.IS", "BIMAS.IS", "AKBNK.IS", "TUPRS.IS", "PGSUS.IS"
]

def rsi_hesapla(series, period=14):
    delta = series.diff()
    gain = (delta.where(delta > 0, 0)).rolling(window=period).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(window=period).mean()
    rs = gain / loss
    rsi = 100 - (100 / (1 + rs))
    return rsi

@app.get("/")
def ana_sayfa():
    return {"durum": "BorsaAI Pro Backend Aktif", "zaman": datetime.now().strftime("%Y-%m-%d %H:%M:%S")}

@app.get("/tara")
def hisseleri_tara():
    firsatlar = []
    
    # Canlı verileri toplu veya tekli çekme
    for sembol in HIZMET_LISTESI:
        try:
            hisse = yf.Ticker(sembol)
            hist = hisse.history(period="1mo") # Son 1 aylık veri
            
            if hist.empty or len(hist) < 15:
                continue
                
            kapanislar = hist['Close']
            guncel_fiyat = float(kapanislar.iloc[-1])
            onceki_fiyat = float(kapanislar.iloc[-2])
            degisim_yuzde = ((guncel_fiyat - onceki_fiyat) / onceki_fiyat) * 100
            
            # RSI Hesaplama
            rsi_serisi = rsi_hesapla(kapanislar)
            guncel_rsi = float(rsi_serisi.iloc[-1]) if not np.isnan(rsi_serisi.iloc[-1]) else 50.0
            
            # Strateji / Detay Belirleme
            detay = "Nötr Seyir"
            if guncel_rsi < 30:
                detay = "Güçlü Alım Bölgesi (Aşırı Satış)"
            elif guncel_rsi > 70:
                detay = "Kar Satışı / Riskli Bölge (Aşırı Alım)"
            elif degisim_yuzde > 2.0:
                detay = "Yükseliş Trendinde"
            elif degisim_yuzde < -2.0:
                detay = "Geri Çekilme Yaşıyor"

            # Temiz kısa isim (ASELS.IS -> ASELS)
            temiz_isim = sembol.replace(".IS", "")

            firsatlar.append({
                "hisse": temiz_isim,
                "fiyat": round(guncel_fiyat, 2),
                "degisim": round(degisim_yuzde, 2),
                "rsi": round(guncel_rsi, 1),
                "detay": detay,
                "gecmis_fiyatlar": [round(float(x), 2) for x in kapanislar.tail(10).tolist()]
            })
        except Exception as e:
            print(f"Hata ({sembol}): {e}")
            continue

    return firsatlar

@app.post("/otomatik_islem_calistir")
def otomatik_islem_calistir():
    # Algoritmik robot simülasyon tetikleyicisi
    # Burada RSI değerlerine göre otomatik emir mekanizmaları simüle edilebilir.
    islem_sayisi = 2
    return {
        "durum": "basarili",
        "mesaj": "Algoritmik tarama ve otomatik işlem kontrolü tamamlandı.",
        "yapilan_islem_sayisi": islem_sayisi
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("borsa_bot:app", host="127.0.0.1", port=8000, reload=True)