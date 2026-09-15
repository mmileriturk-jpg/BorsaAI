import requests
import json

BASE_URL = "http://127.0.0.1:8000"

def testi_baslat():
    print("--- 1. Borsa Taraması Test Ediliyor ---")
    tara_res = requests.get(f"{BASE_URL}/tara")
    if tara_res.status_code == 200:
        hisseler = tara_res.json()
        print(f"Başarılı! Bulunan hisse sayısı: {len(hisseler)}")
        if not hisseler:
            print("Liste boş döndü.")
            return
        
        # Test için listedeki ilk hisseyi seçelim
        ilk_hisse = hisseler[0]
        hisse_adi = ilk_hisse["hisse"]
        fiyat = ilk_hisse["fiyat"]
        print(f"Seçilen Test Hissesi: {hisse_adi} | Fiyat: {fiyat} TL\n")
        
        print("--- 2. Başlangıç Portföyü Kontrol Ediliyor ---")
        portfoy_res = requests.get(f"{BASE_URL}/portfoy")
        print("Cüzdan:", json.dumps(portfoy_res.json(), indent=2, ensure_ascii=False))
        
        print(f"\n--- 3. Sanal Alım Yapılıyor ({hisse_adi}) ---")
        al_payload = {
            "hisse": hisse_adi,
            "islem": "AL",
            "adet": 10,
            "fiyat": fiyat
        }
        al_res = requests.post(f"{BASE_URL}/islem", json=al_payload)
        print("Alım Sonucu:", al_res.json())
        
        print("\n--- 4. Güncel Portföy Kontrol Ediliyor ---")
        portfoy_res2 = requests.get(f"{BASE_URL}/portfoy")
        print("Cüzdan:", json.dumps(portfoy_res2.json(), indent=2, ensure_ascii=False))
        
        print(f"\n--- 5. Sanal Satış Yapılıyor ({hisse_adi}) ---")
        sat_payload = {
            "hisse": hisse_adi,
            "islem": "SAT",
            "adet": 5,
            "fiyat": fiyat
        }
        sat_res = requests.post(f"{BASE_URL}/islem", json=sat_payload)
        print("Satış Sonucu:", sat_res.json())
        
        print("\n--- 6. Son Portföy ve İşlem Geçmişi ---")
        portfoy_res3 = requests.get(f"{BASE_URL}/portfoy")
        print("Cüzdan:", json.dumps(portfoy_res3.json(), indent=2, ensure_ascii=False))
        
    else:
        print("Sunucuya ulaşılamadı! Uvicorn'un açık olduğundan emin ol.")

if __name__ == "__main__":
    testi_baslat()