/* =====================================================================
   ÜNİVERSİTE BİLGİ SİSTEMİ - VERİTABANI OLUŞTURMA SCRİPTİ
   Seçenek A
   İçerik: CREATE TABLE + CONSTRAINT + INDEX + VIEW + STORED PROCEDURE
   ===================================================================== */

IF DB_ID('UniversiteBilgiSistemi') IS NULL
    CREATE DATABASE UniversiteBilgiSistemi;
GO

USE UniversiteBilgiSistemi;
GO

-- Varsa eski tabloları bağımlılık sırasına göre sil (yeniden çalıştırılabilirlik için)
IF OBJECT_ID('dbo.kayit', 'U')           IS NOT NULL DROP TABLE dbo.kayit;
IF OBJECT_ID('dbo.ders', 'U')            IS NOT NULL DROP TABLE dbo.ders;
IF OBJECT_ID('dbo.ogrenci', 'U')         IS NOT NULL DROP TABLE dbo.ogrenci;
IF OBJECT_ID('dbo.ogretim_uyesi', 'U')   IS NOT NULL DROP TABLE dbo.ogretim_uyesi;
IF OBJECT_ID('dbo.bolum', 'U')           IS NOT NULL DROP TABLE dbo.bolum;
GO

/* =====================================================================
   1. BOLUM TABLOSU
   ===================================================================== */
CREATE TABLE dbo.bolum (
    bolum_id    INT             NOT NULL,
    ad          VARCHAR(100)    NOT NULL,
    fakulte     VARCHAR(100)    NOT NULL,
    kontenjan   INT             NOT NULL,
    CONSTRAINT PK_bolum PRIMARY KEY (bolum_id),
    CONSTRAINT CK_bolum_kontenjan CHECK (kontenjan > 0)
);
GO

/* =====================================================================
   2. OGRETIM_UYESI TABLOSU
   ===================================================================== */
CREATE TABLE dbo.ogretim_uyesi (
    id          INT IDENTITY(1,1)  NOT NULL,
    ad          VARCHAR(50)        NOT NULL,
    soyad       VARCHAR(50)        NOT NULL,
    unvan       VARCHAR(20)        NOT NULL,
    bolum_id    INT                NOT NULL,
    e_posta     VARCHAR(100)       NOT NULL,
    ise_giris   DATE               NOT NULL,
    CONSTRAINT PK_ogretim_uyesi PRIMARY KEY (id),
    CONSTRAINT UQ_ogretim_uyesi_eposta UNIQUE (e_posta),
    CONSTRAINT FK_ogretim_uyesi_bolum FOREIGN KEY (bolum_id)
        REFERENCES dbo.bolum(bolum_id),
    CONSTRAINT CK_ogretim_uyesi_unvan CHECK (unvan IN
        ('Prof. Dr.', 'Doç. Dr.', 'Dr. Öğr. Üyesi', 'Öğr. Gör.', 'Arş. Gör.'))
);
GO

/* =====================================================================
   3. OGRENCI TABLOSU
   ===================================================================== */
CREATE TABLE dbo.ogrenci (
    ogrenci_no      INT IDENTITY(1000,1)   NOT NULL,
    ad              VARCHAR(50)            NOT NULL,
    soyad           VARCHAR(50)            NOT NULL,
    tc_kimlik       CHAR(11)               NOT NULL,
    dogum_tarihi    DATE                   NOT NULL,
    cinsiyet        CHAR(1)                NOT NULL,
    bolum_id        INT                    NOT NULL,
    giris_yili      INT                    NOT NULL,
    e_posta         VARCHAR(100)           NULL,
    aktif_mi        BIT                    NOT NULL DEFAULT 1,
    CONSTRAINT PK_ogrenci PRIMARY KEY (ogrenci_no),
    CONSTRAINT UQ_ogrenci_tc UNIQUE (tc_kimlik),
    CONSTRAINT UQ_ogrenci_eposta UNIQUE (e_posta),
    CONSTRAINT FK_ogrenci_bolum FOREIGN KEY (bolum_id)
        REFERENCES dbo.bolum(bolum_id),
    CONSTRAINT CK_ogrenci_cinsiyet CHECK (cinsiyet IN ('E', 'K')),
    CONSTRAINT CK_ogrenci_giris_yili CHECK (giris_yili BETWEEN 2000 AND 2100)
);
GO

/* =====================================================================
   4. DERS TABLOSU
   ===================================================================== */
CREATE TABLE dbo.ders (
    ders_kodu           VARCHAR(10)    NOT NULL,
    ad                  VARCHAR(100)   NOT NULL,
    kredi                INT           NOT NULL,
    ogretim_uyesi_id    INT            NOT NULL,
    donem               VARCHAR(20)    NOT NULL,
    ders_turu           VARCHAR(20)    NOT NULL,
    max_ogrenci         INT            NOT NULL,
    CONSTRAINT PK_ders PRIMARY KEY (ders_kodu),
    CONSTRAINT FK_ders_ogretim_uyesi FOREIGN KEY (ogretim_uyesi_id)
        REFERENCES dbo.ogretim_uyesi(id),
    CONSTRAINT CK_ders_kredi CHECK (kredi BETWEEN 1 AND 6),
    CONSTRAINT CK_ders_donem CHECK (donem IN ('Güz', 'Bahar')),
    CONSTRAINT CK_ders_turu CHECK (ders_turu IN ('Zorunlu', 'Seçmeli')),
    CONSTRAINT CK_ders_max_ogrenci CHECK (max_ogrenci > 0)
);
GO

/* =====================================================================
   5. KAYIT TABLOSU (Öğrenci - Ders ilişki tablosu)
   ===================================================================== */
CREATE TABLE dbo.kayit (
    kayit_id        INT IDENTITY(1,1)  NOT NULL,
    ogrenci_no      INT                NOT NULL,
    ders_kodu       VARCHAR(10)        NOT NULL,
    akademik_yil    VARCHAR(10)        NOT NULL,
    donem           VARCHAR(10)        NOT NULL,
    not_degeri      DECIMAL(4,2)       NULL,
    harf_notu       VARCHAR(3)         NULL,
    kayit_tarihi    DATETIME           NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_kayit PRIMARY KEY (kayit_id),
    CONSTRAINT FK_kayit_ogrenci FOREIGN KEY (ogrenci_no)
        REFERENCES dbo.ogrenci(ogrenci_no),
    CONSTRAINT FK_kayit_ders FOREIGN KEY (ders_kodu)
        REFERENCES dbo.ders(ders_kodu),
    CONSTRAINT CK_kayit_not CHECK (not_degeri BETWEEN 0 AND 100),
    CONSTRAINT UQ_kayit_tekil UNIQUE (ogrenci_no, ders_kodu, akademik_yil, donem)
);
GO

/* =====================================================================
   INDEXLER  (FK kolonları + sık aranan alanlar)
   ===================================================================== */
CREATE INDEX IX_ogrenci_bolum_id          ON dbo.ogrenci(bolum_id);
CREATE INDEX IX_ogretim_uyesi_bolum_id    ON dbo.ogretim_uyesi(bolum_id);
CREATE INDEX IX_ders_ogretim_uyesi_id     ON dbo.ders(ogretim_uyesi_id);
CREATE INDEX IX_kayit_ogrenci_no          ON dbo.kayit(ogrenci_no);
CREATE INDEX IX_kayit_ders_kodu           ON dbo.kayit(ders_kodu);
CREATE INDEX IX_ogrenci_adsoyad           ON dbo.ogrenci(soyad, ad);
GO

/* =====================================================================
   VIEW 1: Öğrenci Genel Not Ortalaması (GPA görünümü)
   ===================================================================== */
CREATE VIEW dbo.vw_OgrenciGenelOrtalama AS
SELECT
    o.ogrenci_no,
    o.ad,
    o.soyad,
    b.ad                                AS bolum_adi,
    COUNT(k.kayit_id)                   AS alinan_ders_sayisi,
    AVG(k.not_degeri)                   AS not_ortalamasi
FROM dbo.ogrenci o
INNER JOIN dbo.bolum b  ON o.bolum_id = b.bolum_id
LEFT  JOIN dbo.kayit k  ON o.ogrenci_no = k.ogrenci_no AND k.not_degeri IS NOT NULL
GROUP BY o.ogrenci_no, o.ad, o.soyad, b.ad;
GO

/* =====================================================================
   VIEW 2: Ders Bazlı Doluluk Durumu
   ===================================================================== */
CREATE VIEW dbo.vw_DersDolulukDurumu AS
SELECT
    d.ders_kodu,
    d.ad                                  AS ders_adi,
    d.max_ogrenci,
    COUNT(k.kayit_id)                     AS kayitli_ogrenci_sayisi,
    d.max_ogrenci - COUNT(k.kayit_id)     AS bos_kontenjan
FROM dbo.ders d
LEFT JOIN dbo.kayit k ON d.ders_kodu = k.ders_kodu
GROUP BY d.ders_kodu, d.ad, d.max_ogrenci;
GO

/* =====================================================================
   STORED PROCEDURE: Not Girişi ve Otomatik Harf Notu Hesaplama
   ===================================================================== */
CREATE PROCEDURE dbo.sp_NotGir
    @kayit_id     INT,
    @not_degeri   DECIMAL(4,2)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @harf_notu VARCHAR(3);

    SET @harf_notu =
        CASE
            WHEN @not_degeri >= 90 THEN 'AA'
            WHEN @not_degeri >= 85 THEN 'BA'
            WHEN @not_degeri >= 80 THEN 'BB'
            WHEN @not_degeri >= 75 THEN 'CB'
            WHEN @not_degeri >= 70 THEN 'CC'
            WHEN @not_degeri >= 65 THEN 'DC'
            WHEN @not_degeri >= 60 THEN 'DD'
            ELSE 'FF'
        END;

    UPDATE dbo.kayit
    SET not_degeri = @not_degeri,
        harf_notu  = @harf_notu
    WHERE kayit_id = @kayit_id;
END;
GO

/* =====================================================================
   ÖRNEK SORGULAR (Test ve gösterim amaçlı - Teknik Dokümantasyonda
   da yer almaktadır)
   ===================================================================== */

-- JOIN 1: Bir öğrencinin tüm dersleri ve notları
-- SELECT o.ad, o.soyad, d.ad AS ders_adi, k.not_degeri, k.harf_notu
-- FROM ogrenci o
-- INNER JOIN kayit k ON o.ogrenci_no = k.ogrenci_no
-- INNER JOIN ders d  ON k.ders_kodu = d.ders_kodu
-- WHERE o.ogrenci_no = 1005;

-- JOIN 2: Bir öğretim üyesinin verdiği derslerdeki öğrenci listesi
-- SELECT ou.ad, ou.soyad, d.ad AS ders_adi, o.ad AS ogrenci_adi, o.soyad AS ogrenci_soyadi
-- FROM ogretim_uyesi ou
-- INNER JOIN ders d   ON ou.id = d.ogretim_uyesi_id
-- INNER JOIN kayit k  ON d.ders_kodu = k.ders_kodu
-- INNER JOIN ogrenci o ON k.ogrenci_no = o.ogrenci_no
-- WHERE ou.id = 3;

-- JOIN 3 (LEFT JOIN): Hiç ders almamış öğrencileri de dahil ederek tüm öğrenci-kayıt listesi
-- SELECT o.ad, o.soyad, k.ders_kodu
-- FROM ogrenci o
-- LEFT JOIN kayit k ON o.ogrenci_no = k.ogrenci_no;

-- GROUP BY + HAVING: Ortalaması 70 üzerinde olan öğrenciler
-- SELECT ogrenci_no, ad, soyad, not_ortalamasi
-- FROM vw_OgrenciGenelOrtalama
-- HAVING not_ortalamasi > 70;

-- SUBQUERY: En yüksek not alan öğrenci
-- SELECT o.ad, o.soyad, k.not_degeri
-- FROM ogrenci o
-- INNER JOIN kayit k ON o.ogrenci_no = k.ogrenci_no
-- WHERE k.not_degeri = (SELECT MAX(not_degeri) FROM kayit);
