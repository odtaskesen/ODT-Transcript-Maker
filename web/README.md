# Web sürümü

Mac uygulamasından ayrı, bağımsız bir projedir. Derleme aracı gerekmez;
düz HTML/JS dosyalarıdır, herhangi bir statik sunucuyla (örn. `python3 -m
http.server`) servis edilebilir.

- `spike/` — fizibilite denemesi (bkz. `docs/WEB_VERSION_PLAN.md`). Tek
  sayfalık, atılabilir bir test; ürünün parçası değildir.
- `app/` — lite sürümün kendisi. Açmak için:

  ```bash
  cd web/app
  python3 -m http.server 8744
  ```

  Sonra tarayıcıda `http://localhost:8744` adresini açın. Chrome veya Edge
  önerilir (WebGPU gerekir).

Ayrıntılar ve tasarım kararları için `docs/WEB_VERSION_PLAN.md`.
