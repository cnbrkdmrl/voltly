import Foundation

public struct ReferenceVehicleSpec: Equatable {
    public let brand: String
    public let model: String
    public let trim: String?
    public let year: Int
    public let enginePowerHP: Double
    public let enginePowerKW: Double
    public let acMaxChargingKW: Double
    public let dcMaxChargingKW: Double
    public let batteryCapacityKWh: Double
    public let factoryConsumptionKWh100km: Double
    public let silhouetteKey: String

    public init(
        brand: String,
        model: String,
        trim: String? = nil,
        year: Int,
        enginePowerHP: Double,
        enginePowerKW: Double,
        acMaxChargingKW: Double,
        dcMaxChargingKW: Double,
        batteryCapacityKWh: Double,
        factoryConsumptionKWh100km: Double,
        silhouetteKey: String
    ) {
        self.brand = brand
        self.model = model
        self.trim = trim
        self.year = year
        self.enginePowerHP = enginePowerHP
        self.enginePowerKW = enginePowerKW
        self.acMaxChargingKW = acMaxChargingKW
        self.dcMaxChargingKW = dcMaxChargingKW
        self.batteryCapacityKWh = batteryCapacityKWh
        self.factoryConsumptionKWh100km = factoryConsumptionKWh100km
        self.silhouetteKey = silhouetteKey
    }
}

public protocol ReferenceVehicleCatalogProviding {
    func all() -> [ReferenceVehicleSpec]
    func find(brand: String, model: String, year: Int) -> ReferenceVehicleSpec?
    func find(brand: String, model: String, trim: String?, year: Int) -> ReferenceVehicleSpec?
}

public final class StaticReferenceVehicleCatalog: ReferenceVehicleCatalogProviding {
    private let items: [ReferenceVehicleSpec] = [
        // Hyundai
        .init(
            brand: "Hyundai",
            model: "IONIQ 5",
            year: 2023,
            enginePowerHP: 229,
            enginePowerKW: 168,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 220,
            batteryCapacityKWh: 77.4,
            factoryConsumptionKWh100km: 18.0,
            silhouetteKey: "hyundai_ioniq5_2023"
        ),
        .init(
            brand: "Hyundai",
            model: "IONIQ 5",
            year: 2024,
            enginePowerHP: 229,
            enginePowerKW: 168,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 233,
            batteryCapacityKWh: 84,
            factoryConsumptionKWh100km: 16.9,
            silhouetteKey: "hyundai_ioniq5_2024"
        ),
        .init(
            brand: "Hyundai",
            model: "IONIQ 6",
            year: 2023,
            enginePowerHP: 229,
            enginePowerKW: 168,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 233,
            batteryCapacityKWh: 77.4,
            factoryConsumptionKWh100km: 14.9,
            silhouetteKey: "hyundai_ioniq6_2023"
        ),
        .init(
            brand: "Hyundai",
            model: "IONIQ 6",
            year: 2024,
            enginePowerHP: 229,
            enginePowerKW: 168,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 233,
            batteryCapacityKWh: 77.4,
            factoryConsumptionKWh100km: 14.3,
            silhouetteKey: "hyundai_ioniq6_2024"
        ),
        .init(
            brand: "Hyundai",
            model: "Kona Electric",
            year: 2023,
            enginePowerHP: 204,
            enginePowerKW: 150,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 102,
            batteryCapacityKWh: 64.8,
            factoryConsumptionKWh100km: 14.7,
            silhouetteKey: "hyundai_kona_electric_2023"
        ),
        .init(
            brand: "Hyundai",
            model: "Kona Electric",
            year: 2024,
            enginePowerHP: 204,
            enginePowerKW: 150,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 102,
            batteryCapacityKWh: 65.4,
            factoryConsumptionKWh100km: 14.7,
            silhouetteKey: "hyundai_kona_electric_2024"
        ),
        .init(
            brand: "Hyundai",
            model: "INSTER",
            year: 2025,
            enginePowerHP: 115,
            enginePowerKW: 85,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 120,
            batteryCapacityKWh: 49,
            factoryConsumptionKWh100km: 15.1,
            silhouetteKey: "hyundai_inster_2025"
        ),
        .init(
            brand: "Hyundai",
            model: "IONIQ 9",
            year: 2025,
            enginePowerHP: 313,
            enginePowerKW: 230,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 233,
            batteryCapacityKWh: 110,
            factoryConsumptionKWh100km: 20.1,
            silhouetteKey: "hyundai_ioniq9_2025"
        ),

        // Tesla
        .init(
            brand: "Tesla",
            model: "Model 3",
            year: 2023,
            enginePowerHP: 283,
            enginePowerKW: 208,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 170,
            batteryCapacityKWh: 60,
            factoryConsumptionKWh100km: 14.0,
            silhouetteKey: "tesla_model3_2023"
        ),
        .init(
            brand: "Tesla",
            model: "Model 3",
            year: 2024,
            enginePowerHP: 283,
            enginePowerKW: 208,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 170,
            batteryCapacityKWh: 60,
            factoryConsumptionKWh100km: 13.2,
            silhouetteKey: "tesla_model3_2024"
        ),
        .init(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            enginePowerHP: 213,
            enginePowerKW: 157,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 160,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 17.7,
            silhouetteKey: "opel_grandland_2025"
        ),
        .init(
            brand: "Tesla",
            model: "Model Y",
            year: 2023,
            enginePowerHP: 347,
            enginePowerKW: 255,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 250,
            batteryCapacityKWh: 75,
            factoryConsumptionKWh100km: 16.9,
            silhouetteKey: "tesla_model_y_2023"
        ),
        .init(
            brand: "Tesla",
            model: "Model Y",
            year: 2024,
            enginePowerHP: 347,
            enginePowerKW: 255,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 250,
            batteryCapacityKWh: 75,
            factoryConsumptionKWh100km: 15.7,
            silhouetteKey: "tesla_model_y_2024"
        ),
        .init(
            brand: "Tesla",
            model: "Model S",
            year: 2024,
            enginePowerHP: 670,
            enginePowerKW: 493,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 250,
            batteryCapacityKWh: 100,
            factoryConsumptionKWh100km: 18.7,
            silhouetteKey: "tesla_model_s_2024"
        ),
        .init(
            brand: "Tesla",
            model: "Model X",
            year: 2024,
            enginePowerHP: 670,
            enginePowerKW: 493,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 250,
            batteryCapacityKWh: 100,
            factoryConsumptionKWh100km: 21.1,
            silhouetteKey: "tesla_model_x_2024"
        ),

        // Opel
        .init(
            brand: "Opel",
            model: "Astra Electric",
            year: 2024,
            enginePowerHP: 156,
            enginePowerKW: 115,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 100,
            batteryCapacityKWh: 54,
            factoryConsumptionKWh100km: 15.1,
            silhouetteKey: "opel_astra_electric_2024"
        ),
        .init(
            brand: "Opel",
            model: "Corsa Electric",
            year: 2024,
            enginePowerHP: 156,
            enginePowerKW: 115,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 100,
            batteryCapacityKWh: 51,
            factoryConsumptionKWh100km: 15.6,
            silhouetteKey: "opel_corsa_electric_2024"
        ),
        .init(
            brand: "Opel",
            model: "Mokka Electric",
            year: 2024,
            enginePowerHP: 156,
            enginePowerKW: 115,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 100,
            batteryCapacityKWh: 54,
            factoryConsumptionKWh100km: 15.8,
            silhouetteKey: "opel_mokka_electric_2024"
        ),

        // Peugeot
        .init(
            brand: "Peugeot",
            model: "E-208",
            year: 2024,
            enginePowerHP: 156,
            enginePowerKW: 115,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 100,
            batteryCapacityKWh: 51,
            factoryConsumptionKWh100km: 15.4,
            silhouetteKey: "peugeot_e208_2024"
        ),
        .init(
            brand: "Peugeot",
            model: "E-2008",
            year: 2024,
            enginePowerHP: 156,
            enginePowerKW: 115,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 100,
            batteryCapacityKWh: 54,
            factoryConsumptionKWh100km: 16.0,
            silhouetteKey: "peugeot_e2008_2024"
        ),
        .init(
            brand: "Peugeot",
            model: "E-308",
            year: 2024,
            enginePowerHP: 156,
            enginePowerKW: 115,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 100,
            batteryCapacityKWh: 54,
            factoryConsumptionKWh100km: 15.5,
            silhouetteKey: "peugeot_e308_2024"
        ),
        .init(
            brand: "Peugeot",
            model: "E-3008",
            year: 2025,
            enginePowerHP: 213,
            enginePowerKW: 157,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 160,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 17.9,
            silhouetteKey: "peugeot_e3008_2025"
        ),

        // Togg
        .init(
            brand: "Togg",
            model: "T10X",
            trim: "Standart Menzil",
            year: 2023,
            enginePowerHP: 218,
            enginePowerKW: 160,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 180,
            batteryCapacityKWh: 52.4,
            factoryConsumptionKWh100km: 17.1,
            silhouetteKey: "togg_t10x_standard_2023"
        ),
        .init(
            brand: "Togg",
            model: "T10X",
            trim: "Standart Menzil",
            year: 2024,
            enginePowerHP: 218,
            enginePowerKW: 160,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 180,
            batteryCapacityKWh: 52.4,
            factoryConsumptionKWh100km: 16.9,
            silhouetteKey: "togg_t10x_standard_2024"
        ),
        .init(
            brand: "Togg",
            model: "T10X",
            trim: "Uzun Menzil",
            year: 2023,
            enginePowerHP: 218,
            enginePowerKW: 160,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 180,
            batteryCapacityKWh: 88.5,
            factoryConsumptionKWh100km: 18.5,
            silhouetteKey: "togg_t10x_long_2023"
        ),
        .init(
            brand: "Togg",
            model: "T10X",
            trim: "Uzun Menzil",
            year: 2024,
            enginePowerHP: 218,
            enginePowerKW: 160,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 180,
            batteryCapacityKWh: 88.5,
            factoryConsumptionKWh100km: 18.3,
            silhouetteKey: "togg_t10x_long_2024"
        ),
        .init(
            brand: "Togg",
            model: "T10X",
            trim: "Standart Menzil",
            year: 2025,
            enginePowerHP: 218,
            enginePowerKW: 160,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 180,
            batteryCapacityKWh: 52.4,
            factoryConsumptionKWh100km: 16.7,
            silhouetteKey: "togg_t10x_standard_2025"
        ),
        .init(
            brand: "Togg",
            model: "T10X",
            trim: "Uzun Menzil",
            year: 2025,
            enginePowerHP: 218,
            enginePowerKW: 160,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 180,
            batteryCapacityKWh: 88.5,
            factoryConsumptionKWh100km: 18.1,
            silhouetteKey: "togg_t10x_long_2025"
        ),
        .init(
            brand: "Togg",
            model: "T10F",
            year: 2025,
            enginePowerHP: 218,
            enginePowerKW: 160,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 180,
            batteryCapacityKWh: 88.5,
            factoryConsumptionKWh100km: 17.6,
            silhouetteKey: "togg_t10f_2025"
        ),

        // MG
        .init(
            brand: "MG",
            model: "MG4 Electric",
            year: 2023,
            enginePowerHP: 204,
            enginePowerKW: 150,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 135,
            batteryCapacityKWh: 64,
            factoryConsumptionKWh100km: 16.8,
            silhouetteKey: "mg_mg4_2023"
        ),
        .init(
            brand: "MG",
            model: "MG4 Electric",
            year: 2024,
            enginePowerHP: 204,
            enginePowerKW: 150,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 140,
            batteryCapacityKWh: 64,
            factoryConsumptionKWh100km: 16.5,
            silhouetteKey: "mg_mg4_2024"
        ),
        .init(
            brand: "MG",
            model: "MG5 Electric",
            year: 2024,
            enginePowerHP: 156,
            enginePowerKW: 115,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 87,
            batteryCapacityKWh: 61.1,
            factoryConsumptionKWh100km: 17.5,
            silhouetteKey: "mg_mg5_2024"
        ),
        .init(
            brand: "MG",
            model: "Marvel R",
            year: 2024,
            enginePowerHP: 180,
            enginePowerKW: 132,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 94,
            batteryCapacityKWh: 70,
            factoryConsumptionKWh100km: 19.4,
            silhouetteKey: "mg_marvel_r_2024"
        ),
        .init(
            brand: "MG",
            model: "ZS EV",
            year: 2024,
            enginePowerHP: 156,
            enginePowerKW: 115,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 92,
            batteryCapacityKWh: 72.6,
            factoryConsumptionKWh100km: 17.8,
            silhouetteKey: "mg_zs_ev_2024"
        ),

        // BYD
        .init(
            brand: "BYD",
            model: "ATTO 3",
            year: 2023,
            enginePowerHP: 204,
            enginePowerKW: 150,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 88,
            batteryCapacityKWh: 60.5,
            factoryConsumptionKWh100km: 17.6,
            silhouetteKey: "byd_atto3_2023"
        ),
        .init(
            brand: "BYD",
            model: "ATTO 3",
            year: 2024,
            enginePowerHP: 204,
            enginePowerKW: 150,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 88,
            batteryCapacityKWh: 60.5,
            factoryConsumptionKWh100km: 17.3,
            silhouetteKey: "byd_atto3_2024"
        ),
        .init(
            brand: "BYD",
            model: "Dolphin",
            year: 2024,
            enginePowerHP: 204,
            enginePowerKW: 150,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 88,
            batteryCapacityKWh: 60.4,
            factoryConsumptionKWh100km: 15.9,
            silhouetteKey: "byd_dolphin_2024"
        ),
        .init(
            brand: "BYD",
            model: "HAN",
            year: 2024,
            enginePowerHP: 517,
            enginePowerKW: 380,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 120,
            batteryCapacityKWh: 85.4,
            factoryConsumptionKWh100km: 18.5,
            silhouetteKey: "byd_han_2024"
        ),
        .init(
            brand: "BYD",
            model: "Seal",
            year: 2024,
            enginePowerHP: 313,
            enginePowerKW: 230,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 150,
            batteryCapacityKWh: 82.5,
            factoryConsumptionKWh100km: 16.6,
            silhouetteKey: "byd_seal_2024"
        ),
        .init(
            brand: "BYD",
            model: "Seal U EV",
            year: 2025,
            enginePowerHP: 218,
            enginePowerKW: 160,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 140,
            batteryCapacityKWh: 87,
            factoryConsumptionKWh100km: 18.0,
            silhouetteKey: "byd_seal_u_2025"
        ),

        // Mercedes
        .init(
            brand: "Mercedes",
            model: "EQA 250+",
            year: 2024,
            enginePowerHP: 190,
            enginePowerKW: 140,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 100,
            batteryCapacityKWh: 70.5,
            factoryConsumptionKWh100km: 16.2,
            silhouetteKey: "mercedes_eqa_2024"
        ),
        .init(
            brand: "Mercedes",
            model: "EQB 250+",
            year: 2024,
            enginePowerHP: 190,
            enginePowerKW: 140,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 100,
            batteryCapacityKWh: 70.5,
            factoryConsumptionKWh100km: 17.1,
            silhouetteKey: "mercedes_eqb_2024"
        ),
        .init(
            brand: "Mercedes",
            model: "EQE 350+",
            year: 2024,
            enginePowerHP: 292,
            enginePowerKW: 215,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 170,
            batteryCapacityKWh: 96,
            factoryConsumptionKWh100km: 17.7,
            silhouetteKey: "mercedes_eqe_2024"
        ),
        .init(
            brand: "Mercedes",
            model: "EQE SUV 350+",
            year: 2024,
            enginePowerHP: 292,
            enginePowerKW: 215,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 170,
            batteryCapacityKWh: 96,
            factoryConsumptionKWh100km: 19.5,
            silhouetteKey: "mercedes_eqe_suv_2024"
        ),
        .init(
            brand: "Mercedes",
            model: "EQS 450+",
            year: 2024,
            enginePowerHP: 360,
            enginePowerKW: 265,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 200,
            batteryCapacityKWh: 118,
            factoryConsumptionKWh100km: 17.8,
            silhouetteKey: "mercedes_eqs_2024"
        ),
        .init(
            brand: "Mercedes",
            model: "EQV 300",
            year: 2024,
            enginePowerHP: 204,
            enginePowerKW: 150,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 110,
            batteryCapacityKWh: 90,
            factoryConsumptionKWh100km: 28.6,
            silhouetteKey: "mercedes_eqv_2024"
        ),

        // BMW
        .init(
            brand: "BMW",
            model: "i4 eDrive40",
            year: 2024,
            enginePowerHP: 340,
            enginePowerKW: 250,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 205,
            batteryCapacityKWh: 83.9,
            factoryConsumptionKWh100km: 16.1,
            silhouetteKey: "bmw_i4_2024"
        ),
        .init(
            brand: "BMW",
            model: "i5 eDrive40",
            year: 2024,
            enginePowerHP: 340,
            enginePowerKW: 250,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 205,
            batteryCapacityKWh: 81.2,
            factoryConsumptionKWh100km: 17.9,
            silhouetteKey: "bmw_i5_2024"
        ),
        .init(
            brand: "BMW",
            model: "iX xDrive40",
            year: 2024,
            enginePowerHP: 326,
            enginePowerKW: 240,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 150,
            batteryCapacityKWh: 76.6,
            factoryConsumptionKWh100km: 20.9,
            silhouetteKey: "bmw_ix_2024"
        ),
        .init(
            brand: "BMW",
            model: "iX1 eDrive20",
            year: 2024,
            enginePowerHP: 204,
            enginePowerKW: 150,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 130,
            batteryCapacityKWh: 64.7,
            factoryConsumptionKWh100km: 17.1,
            silhouetteKey: "bmw_ix1_2024"
        ),
        .init(
            brand: "BMW",
            model: "iX2 xDrive30",
            year: 2024,
            enginePowerHP: 313,
            enginePowerKW: 230,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 130,
            batteryCapacityKWh: 64.7,
            factoryConsumptionKWh100km: 17.7,
            silhouetteKey: "bmw_ix2_xdrive30_2024"
        ),
        .init(
            brand: "BMW",
            model: "i7 xDrive60",
            year: 2024,
            enginePowerHP: 544,
            enginePowerKW: 400,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 195,
            batteryCapacityKWh: 105.7,
            factoryConsumptionKWh100km: 19.8,
            silhouetteKey: "bmw_i7_xdrive60_2024"
        ),

        // Audi
        .init(
            brand: "Audi",
            model: "A6 e-tron",
            year: 2025,
            enginePowerHP: 367,
            enginePowerKW: 270,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 270,
            batteryCapacityKWh: 100,
            factoryConsumptionKWh100km: 15.9,
            silhouetteKey: "audi_a6_etron_2025"
        ),
        .init(
            brand: "Audi",
            model: "e-tron GT",
            trim: "quattro",
            year: 2024,
            enginePowerHP: 530,
            enginePowerKW: 390,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 270,
            batteryCapacityKWh: 93.4,
            factoryConsumptionKWh100km: 20.0,
            silhouetteKey: "audi_etron_gt_2024"
        ),
        .init(
            brand: "Audi",
            model: "Q4 e-tron 45",
            year: 2024,
            enginePowerHP: 286,
            enginePowerKW: 210,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 175,
            batteryCapacityKWh: 82,
            factoryConsumptionKWh100km: 18.1,
            silhouetteKey: "audi_q4_etron_2024"
        ),
        .init(
            brand: "Audi",
            model: "Q8 e-tron 50",
            year: 2024,
            enginePowerHP: 340,
            enginePowerKW: 250,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 150,
            batteryCapacityKWh: 95,
            factoryConsumptionKWh100km: 22.2,
            silhouetteKey: "audi_q8_etron_2024"
        ),

        // Citroen
        .init(
            brand: "Citroen",
            model: "e-Berlingo",
            year: 2024,
            enginePowerHP: 136,
            enginePowerKW: 100,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 100,
            batteryCapacityKWh: 52,
            factoryConsumptionKWh100km: 19.2,
            silhouetteKey: "citroen_eberlingo_2024"
        ),
        .init(
            brand: "Citroen",
            model: "e-C4",
            year: 2024,
            enginePowerHP: 156,
            enginePowerKW: 115,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 100,
            batteryCapacityKWh: 54,
            factoryConsumptionKWh100km: 15.7,
            silhouetteKey: "citroen_ec4_2024"
        ),
        .init(
            brand: "Citroen",
            model: "e-C4 X",
            year: 2024,
            enginePowerHP: 156,
            enginePowerKW: 115,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 100,
            batteryCapacityKWh: 54,
            factoryConsumptionKWh100km: 15.8,
            silhouetteKey: "citroen_ec4x_2024"
        ),
        .init(
            brand: "Citroen",
            model: "e-C3",
            year: 2025,
            enginePowerHP: 113,
            enginePowerKW: 83,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 100,
            batteryCapacityKWh: 44,
            factoryConsumptionKWh100km: 16.7,
            silhouetteKey: "citroen_ec3_2025"
        ),
        .init(
            brand: "Citroen",
            model: "e-SpaceTourer",
            year: 2024,
            enginePowerHP: 136,
            enginePowerKW: 100,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 100,
            batteryCapacityKWh: 75,
            factoryConsumptionKWh100km: 25.0,
            silhouetteKey: "citroen_espacetourer_2024"
        ),

        // Cupra
        .init(
            brand: "Cupra",
            model: "Born",
            year: 2024,
            enginePowerHP: 231,
            enginePowerKW: 170,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 170,
            batteryCapacityKWh: 77,
            factoryConsumptionKWh100km: 15.8,
            silhouetteKey: "cupra_born_2024"
        ),
        .init(
            brand: "Cupra",
            model: "Tavascan",
            year: 2025,
            enginePowerHP: 286,
            enginePowerKW: 210,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 135,
            batteryCapacityKWh: 82,
            factoryConsumptionKWh100km: 17.7,
            silhouetteKey: "cupra_tavascan_2025"
        ),

        // Fiat
        .init(
            brand: "Fiat",
            model: "500e",
            year: 2024,
            enginePowerHP: 118,
            enginePowerKW: 87,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 85,
            batteryCapacityKWh: 42,
            factoryConsumptionKWh100km: 14.2,
            silhouetteKey: "fiat_500e_2024"
        ),
        .init(
            brand: "Fiat",
            model: "600e",
            year: 2024,
            enginePowerHP: 156,
            enginePowerKW: 115,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 100,
            batteryCapacityKWh: 54,
            factoryConsumptionKWh100km: 15.2,
            silhouetteKey: "fiat_600e_2024"
        ),
        .init(
            brand: "Fiat",
            model: "E-Ulysse",
            year: 2024,
            enginePowerHP: 136,
            enginePowerKW: 100,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 100,
            batteryCapacityKWh: 75,
            factoryConsumptionKWh100km: 24.3,
            silhouetteKey: "fiat_eulysse_2024"
        ),
        .init(
            brand: "Fiat",
            model: "E-Doblo",
            year: 2024,
            enginePowerHP: 136,
            enginePowerKW: 100,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 100,
            batteryCapacityKWh: 52,
            factoryConsumptionKWh100km: 21.5,
            silhouetteKey: "fiat_edoblo_2024"
        ),
        .init(
            brand: "Fiat",
            model: "Topolino",
            year: 2024,
            enginePowerHP: 8,
            enginePowerKW: 6,
            acMaxChargingKW: 2.3,
            dcMaxChargingKW: 0,
            batteryCapacityKWh: 5.5,
            factoryConsumptionKWh100km: 7.5,
            silhouetteKey: "fiat_topolino_2024"
        ),

        // Honda
        .init(
            brand: "Honda",
            model: "e:NY1",
            year: 2024,
            enginePowerHP: 204,
            enginePowerKW: 150,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 78,
            batteryCapacityKWh: 68.8,
            factoryConsumptionKWh100km: 18.2,
            silhouetteKey: "honda_eny1_2024"
        ),
        .init(
            brand: "Honda",
            model: "Honda e",
            year: 2021,
            enginePowerHP: 154,
            enginePowerKW: 113,
            acMaxChargingKW: 6.6,
            dcMaxChargingKW: 56,
            batteryCapacityKWh: 35.5,
            factoryConsumptionKWh100km: 17.2,
            silhouetteKey: "honda_e_2021"
        ),

        // Mini
        .init(
            brand: "Mini",
            model: "Cooper E",
            year: 2024,
            enginePowerHP: 184,
            enginePowerKW: 135,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 75,
            batteryCapacityKWh: 40.7,
            factoryConsumptionKWh100km: 14.7,
            silhouetteKey: "mini_cooper_e_2024"
        ),
        .init(
            brand: "Mini",
            model: "Cooper SE",
            year: 2024,
            enginePowerHP: 218,
            enginePowerKW: 160,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 95,
            batteryCapacityKWh: 54.2,
            factoryConsumptionKWh100km: 15.4,
            silhouetteKey: "mini_cooper_se_2024"
        ),
        .init(
            brand: "Mini",
            model: "Countryman E",
            year: 2024,
            enginePowerHP: 204,
            enginePowerKW: 150,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 130,
            batteryCapacityKWh: 66.5,
            factoryConsumptionKWh100km: 17.4,
            silhouetteKey: "mini_countryman_e_2024"
        ),

        // Porsche
        .init(
            brand: "Porsche",
            model: "Macan 4 Electric",
            year: 2025,
            enginePowerHP: 408,
            enginePowerKW: 300,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 270,
            batteryCapacityKWh: 100,
            factoryConsumptionKWh100km: 17.9,
            silhouetteKey: "porsche_macan4_2025"
        ),
        .init(
            brand: "Porsche",
            model: "Taycan",
            year: 2024,
            enginePowerHP: 408,
            enginePowerKW: 300,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 270,
            batteryCapacityKWh: 89,
            factoryConsumptionKWh100km: 20.4,
            silhouetteKey: "porsche_taycan_2024"
        ),
        .init(
            brand: "Porsche",
            model: "Taycan 4S",
            year: 2024,
            enginePowerHP: 544,
            enginePowerKW: 400,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 270,
            batteryCapacityKWh: 105,
            factoryConsumptionKWh100km: 20.7,
            silhouetteKey: "porsche_taycan4s_2024"
        ),

        // Renault
        .init(
            brand: "Renault",
            model: "5 E-Tech",
            year: 2025,
            enginePowerHP: 150,
            enginePowerKW: 110,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 100,
            batteryCapacityKWh: 52,
            factoryConsumptionKWh100km: 15.0,
            silhouetteKey: "renault_5_etech_2025"
        ),
        .init(
            brand: "Renault",
            model: "Megane E-Tech",
            year: 2023,
            enginePowerHP: 220,
            enginePowerKW: 160,
            acMaxChargingKW: 22,
            dcMaxChargingKW: 130,
            batteryCapacityKWh: 60,
            factoryConsumptionKWh100km: 16.5,
            silhouetteKey: "renault_megane_etech_2023"
        ),
        .init(
            brand: "Renault",
            model: "Megane E-Tech",
            year: 2024,
            enginePowerHP: 220,
            enginePowerKW: 160,
            acMaxChargingKW: 22,
            dcMaxChargingKW: 130,
            batteryCapacityKWh: 60,
            factoryConsumptionKWh100km: 16.1,
            silhouetteKey: "renault_megane_etech_2024"
        ),
        .init(
            brand: "Renault",
            model: "Scenic E-Tech",
            year: 2024,
            enginePowerHP: 220,
            enginePowerKW: 160,
            acMaxChargingKW: 22,
            dcMaxChargingKW: 150,
            batteryCapacityKWh: 87,
            factoryConsumptionKWh100km: 16.8,
            silhouetteKey: "renault_scenic_etech_2024"
        ),
        .init(
            brand: "Renault",
            model: "Zoe",
            year: 2024,
            enginePowerHP: 135,
            enginePowerKW: 100,
            acMaxChargingKW: 22,
            dcMaxChargingKW: 50,
            batteryCapacityKWh: 52,
            factoryConsumptionKWh100km: 17.2,
            silhouetteKey: "renault_zoe_2024"
        ),

        // Seat
        .init(
            brand: "Seat",
            model: "Mii Electric",
            year: 2021,
            enginePowerHP: 83,
            enginePowerKW: 61,
            acMaxChargingKW: 7.2,
            dcMaxChargingKW: 40,
            batteryCapacityKWh: 32.3,
            factoryConsumptionKWh100km: 14.4,
            silhouetteKey: "seat_mii_electric_2021"
        ),
        .init(
            brand: "Seat",
            model: "Born",
            year: 2024,
            enginePowerHP: 231,
            enginePowerKW: 170,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 170,
            batteryCapacityKWh: 77,
            factoryConsumptionKWh100km: 15.8,
            silhouetteKey: "seat_born_2024"
        ),

        // Volkswagen
        .init(
            brand: "Volkswagen",
            model: "ID.3 Pro",
            year: 2024,
            enginePowerHP: 204,
            enginePowerKW: 150,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 170,
            batteryCapacityKWh: 59,
            factoryConsumptionKWh100km: 15.3,
            silhouetteKey: "vw_id3_2024"
        ),
        .init(
            brand: "Volkswagen",
            model: "ID.4 Pro",
            year: 2024,
            enginePowerHP: 286,
            enginePowerKW: 210,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 175,
            batteryCapacityKWh: 77,
            factoryConsumptionKWh100km: 17.2,
            silhouetteKey: "vw_id4_2024"
        ),
        .init(
            brand: "Volkswagen",
            model: "ID.5 Pro",
            year: 2024,
            enginePowerHP: 286,
            enginePowerKW: 210,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 175,
            batteryCapacityKWh: 77,
            factoryConsumptionKWh100km: 17.1,
            silhouetteKey: "vw_id5_2024"
        ),
        .init(
            brand: "Volkswagen",
            model: "ID.7 Pro",
            year: 2024,
            enginePowerHP: 286,
            enginePowerKW: 210,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 200,
            batteryCapacityKWh: 77,
            factoryConsumptionKWh100km: 14.7,
            silhouetteKey: "vw_id7_2024"
        ),
        .init(
            brand: "Volkswagen",
            model: "ID. Buzz Pro",
            year: 2024,
            enginePowerHP: 286,
            enginePowerKW: 210,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 185,
            batteryCapacityKWh: 79,
            factoryConsumptionKWh100km: 20.7,
            silhouetteKey: "vw_idbuzz_pro_2024"
        ),
        .init(
            brand: "Volkswagen",
            model: "ID.3 Pro S",
            year: 2024,
            enginePowerHP: 231,
            enginePowerKW: 170,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 185,
            batteryCapacityKWh: 77,
            factoryConsumptionKWh100km: 15.6,
            silhouetteKey: "vw_id3_pros_2024"
        ),

        // Alfa Romeo
        .init(
            brand: "Alfa Romeo",
            model: "Junior Elettrica",
            year: 2025,
            enginePowerHP: 156,
            enginePowerKW: 115,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 100,
            batteryCapacityKWh: 54,
            factoryConsumptionKWh100km: 15.8,
            silhouetteKey: "alfa_junior_2025"
        ),

        // Dacia
        .init(
            brand: "Dacia",
            model: "Spring",
            year: 2024,
            enginePowerHP: 65,
            enginePowerKW: 48,
            acMaxChargingKW: 7,
            dcMaxChargingKW: 30,
            batteryCapacityKWh: 26.8,
            factoryConsumptionKWh100km: 14.5,
            silhouetteKey: "dacia_spring_2024"
        ),

        // Jeep
        .init(
            brand: "Jeep",
            model: "Avenger Electric",
            year: 2024,
            enginePowerHP: 156,
            enginePowerKW: 115,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 100,
            batteryCapacityKWh: 54,
            factoryConsumptionKWh100km: 15.6,
            silhouetteKey: "jeep_avenger_2024"
        ),

        // KGM SsangYong
        .init(
            brand: "KGM SsangYong",
            model: "Korando e-Motion",
            year: 2024,
            enginePowerHP: 190,
            enginePowerKW: 140,
            acMaxChargingKW: 6.6,
            dcMaxChargingKW: 80,
            batteryCapacityKWh: 61.5,
            factoryConsumptionKWh100km: 18.7,
            silhouetteKey: "kgm_korando_emotion_2024"
        ),
        .init(
            brand: "KGM SsangYong",
            model: "Torres EVX",
            year: 2024,
            enginePowerHP: 207,
            enginePowerKW: 152,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 120,
            batteryCapacityKWh: 73.4,
            factoryConsumptionKWh100km: 18.6,
            silhouetteKey: "kgm_torres_evx_2024"
        ),

        // Kia
        .init(
            brand: "Kia",
            model: "EV3",
            trim: "Standard Range",
            year: 2025,
            enginePowerHP: 204,
            enginePowerKW: 150,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 128,
            batteryCapacityKWh: 58.3,
            factoryConsumptionKWh100km: 15.4,
            silhouetteKey: "kia_ev3_sr_2025"
        ),
        .init(
            brand: "Kia",
            model: "EV3",
            trim: "Long Range",
            year: 2025,
            enginePowerHP: 204,
            enginePowerKW: 150,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 128,
            batteryCapacityKWh: 81.4,
            factoryConsumptionKWh100km: 15.9,
            silhouetteKey: "kia_ev3_lr_2025"
        ),
        .init(
            brand: "Kia",
            model: "EV6",
            trim: "Standard Range RWD",
            year: 2024,
            enginePowerHP: 170,
            enginePowerKW: 125,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 180,
            batteryCapacityKWh: 63,
            factoryConsumptionKWh100km: 16.8,
            silhouetteKey: "kia_ev6_sr_rwd_2024"
        ),
        .init(
            brand: "Kia",
            model: "EV6",
            trim: "Standard Range RWD",
            year: 2025,
            enginePowerHP: 170,
            enginePowerKW: 125,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 180,
            batteryCapacityKWh: 63,
            factoryConsumptionKWh100km: 16.5,
            silhouetteKey: "kia_ev6_sr_rwd_2025"
        ),
        .init(
            brand: "Kia",
            model: "EV6",
            trim: "Long Range RWD",
            year: 2024,
            enginePowerHP: 229,
            enginePowerKW: 168,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 258,
            batteryCapacityKWh: 84,
            factoryConsumptionKWh100km: 17.0,
            silhouetteKey: "kia_ev6_lr_rwd_2024"
        ),
        .init(
            brand: "Kia",
            model: "EV6",
            trim: "Long Range RWD",
            year: 2025,
            enginePowerHP: 229,
            enginePowerKW: 168,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 258,
            batteryCapacityKWh: 84,
            factoryConsumptionKWh100km: 16.7,
            silhouetteKey: "kia_ev6_lr_rwd_2025"
        ),
        .init(
            brand: "Kia",
            model: "EV6",
            trim: "Long Range AWD",
            year: 2024,
            enginePowerHP: 325,
            enginePowerKW: 239,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 258,
            batteryCapacityKWh: 84,
            factoryConsumptionKWh100km: 18.3,
            silhouetteKey: "kia_ev6_lr_awd_2024"
        ),
        .init(
            brand: "Kia",
            model: "EV6",
            trim: "Long Range AWD",
            year: 2025,
            enginePowerHP: 325,
            enginePowerKW: 239,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 258,
            batteryCapacityKWh: 84,
            factoryConsumptionKWh100km: 17.9,
            silhouetteKey: "kia_ev6_lr_awd_2025"
        ),
        .init(
            brand: "Kia",
            model: "EV9",
            trim: "Long Range RWD",
            year: 2024,
            enginePowerHP: 204,
            enginePowerKW: 150,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 210,
            batteryCapacityKWh: 99.8,
            factoryConsumptionKWh100km: 20.2,
            silhouetteKey: "kia_ev9_lr_rwd_2024"
        ),
        .init(
            brand: "Kia",
            model: "EV9",
            trim: "Long Range RWD",
            year: 2025,
            enginePowerHP: 204,
            enginePowerKW: 150,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 210,
            batteryCapacityKWh: 99.8,
            factoryConsumptionKWh100km: 19.9,
            silhouetteKey: "kia_ev9_lr_rwd_2025"
        ),
        .init(
            brand: "Kia",
            model: "EV9",
            trim: "AWD",
            year: 2024,
            enginePowerHP: 384,
            enginePowerKW: 282,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 210,
            batteryCapacityKWh: 99.8,
            factoryConsumptionKWh100km: 22.2,
            silhouetteKey: "kia_ev9_awd_2024"
        ),
        .init(
            brand: "Kia",
            model: "EV9",
            trim: "AWD",
            year: 2025,
            enginePowerHP: 384,
            enginePowerKW: 282,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 210,
            batteryCapacityKWh: 99.8,
            factoryConsumptionKWh100km: 21.9,
            silhouetteKey: "kia_ev9_awd_2025"
        ),
        .init(
            brand: "Kia",
            model: "Niro EV",
            year: 2024,
            enginePowerHP: 204,
            enginePowerKW: 150,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 85,
            batteryCapacityKWh: 64.8,
            factoryConsumptionKWh100km: 16.2,
            silhouetteKey: "kia_niro_ev_2024"
        ),
        .init(
            brand: "Kia",
            model: "Niro EV",
            year: 2025,
            enginePowerHP: 204,
            enginePowerKW: 150,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 85,
            batteryCapacityKWh: 64.8,
            factoryConsumptionKWh100km: 16.0,
            silhouetteKey: "kia_niro_ev_2025"
        ),

        // Skywell
        .init(
            brand: "Skywell",
            model: "ET5",
            year: 2024,
            enginePowerHP: 204,
            enginePowerKW: 150,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 80,
            batteryCapacityKWh: 72,
            factoryConsumptionKWh100km: 19.0,
            silhouetteKey: "skywell_et5_2024"
        ),

        // Volvo
        .init(
            brand: "Volvo",
            model: "EC40",
            year: 2024,
            enginePowerHP: 252,
            enginePowerKW: 185,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 205,
            batteryCapacityKWh: 82,
            factoryConsumptionKWh100km: 17.8,
            silhouetteKey: "volvo_ec40_2024"
        ),
        .init(
            brand: "Volvo",
            model: "EX30",
            year: 2025,
            enginePowerHP: 272,
            enginePowerKW: 200,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 153,
            batteryCapacityKWh: 69,
            factoryConsumptionKWh100km: 16.4,
            silhouetteKey: "volvo_ex30_2025"
        ),
        .init(
            brand: "Volvo",
            model: "EX30",
            year: 2024,
            enginePowerHP: 272,
            enginePowerKW: 200,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 153,
            batteryCapacityKWh: 69,
            factoryConsumptionKWh100km: 16.7,
            silhouetteKey: "volvo_ex30_2024"
        ),
        .init(
            brand: "Volvo",
            model: "EX40",
            year: 2024,
            enginePowerHP: 252,
            enginePowerKW: 185,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 205,
            batteryCapacityKWh: 82,
            factoryConsumptionKWh100km: 17.5,
            silhouetteKey: "volvo_ex40_2024"
        ),
        .init(
            brand: "Volvo",
            model: "EX90",
            year: 2025,
            enginePowerHP: 408,
            enginePowerKW: 300,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 250,
            batteryCapacityKWh: 111,
            factoryConsumptionKWh100km: 20.2,
            silhouetteKey: "volvo_ex90_2025"
        ),

        // Marka bazli yil genisletmeleri
        .init(
            brand: "Alfa Romeo",
            model: "Junior Elettrica",
            year: 2026,
            enginePowerHP: 156,
            enginePowerKW: 115,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 100,
            batteryCapacityKWh: 54,
            factoryConsumptionKWh100km: 15.7,
            silhouetteKey: "alfa_junior_2026"
        ),
        .init(
            brand: "Audi",
            model: "Q4 e-tron 45",
            year: 2023,
            enginePowerHP: 286,
            enginePowerKW: 210,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 135,
            batteryCapacityKWh: 82,
            factoryConsumptionKWh100km: 18.6,
            silhouetteKey: "audi_q4_etron_2023"
        ),
        .init(
            brand: "BMW",
            model: "i4 eDrive40",
            year: 2023,
            enginePowerHP: 340,
            enginePowerKW: 250,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 205,
            batteryCapacityKWh: 83.9,
            factoryConsumptionKWh100km: 16.5,
            silhouetteKey: "bmw_i4_2023"
        ),
        .init(
            brand: "BMW",
            model: "iX1 eDrive20",
            year: 2023,
            enginePowerHP: 204,
            enginePowerKW: 150,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 130,
            batteryCapacityKWh: 64.7,
            factoryConsumptionKWh100km: 17.6,
            silhouetteKey: "bmw_ix1_2023"
        ),
        .init(
            brand: "Citroen",
            model: "e-C4",
            year: 2023,
            enginePowerHP: 156,
            enginePowerKW: 115,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 100,
            batteryCapacityKWh: 54,
            factoryConsumptionKWh100km: 16.0,
            silhouetteKey: "citroen_ec4_2023"
        ),
        .init(
            brand: "Cupra",
            model: "Born",
            year: 2023,
            enginePowerHP: 204,
            enginePowerKW: 150,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 135,
            batteryCapacityKWh: 58,
            factoryConsumptionKWh100km: 16.3,
            silhouetteKey: "cupra_born_2023"
        ),
        .init(
            brand: "Dacia",
            model: "Spring",
            year: 2023,
            enginePowerHP: 65,
            enginePowerKW: 48,
            acMaxChargingKW: 7,
            dcMaxChargingKW: 30,
            batteryCapacityKWh: 26.8,
            factoryConsumptionKWh100km: 14.8,
            silhouetteKey: "dacia_spring_2023"
        ),
        .init(
            brand: "Fiat",
            model: "500e",
            year: 2023,
            enginePowerHP: 118,
            enginePowerKW: 87,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 85,
            batteryCapacityKWh: 42,
            factoryConsumptionKWh100km: 14.6,
            silhouetteKey: "fiat_500e_2023"
        ),
        .init(
            brand: "Honda",
            model: "e:NY1",
            year: 2025,
            enginePowerHP: 204,
            enginePowerKW: 150,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 78,
            batteryCapacityKWh: 68.8,
            factoryConsumptionKWh100km: 18.0,
            silhouetteKey: "honda_eny1_2025"
        ),
        .init(
            brand: "Jeep",
            model: "Avenger Electric",
            year: 2025,
            enginePowerHP: 156,
            enginePowerKW: 115,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 100,
            batteryCapacityKWh: 54,
            factoryConsumptionKWh100km: 15.5,
            silhouetteKey: "jeep_avenger_2025"
        ),
        .init(
            brand: "KGM SsangYong",
            model: "Torres EVX",
            year: 2025,
            enginePowerHP: 207,
            enginePowerKW: 152,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 120,
            batteryCapacityKWh: 73.4,
            factoryConsumptionKWh100km: 18.4,
            silhouetteKey: "kgm_torres_evx_2025"
        ),
        .init(
            brand: "Mercedes",
            model: "EQA 250+",
            year: 2023,
            enginePowerHP: 190,
            enginePowerKW: 140,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 100,
            batteryCapacityKWh: 70.5,
            factoryConsumptionKWh100km: 16.5,
            silhouetteKey: "mercedes_eqa_2023"
        ),
        .init(
            brand: "Mini",
            model: "Cooper SE",
            year: 2025,
            enginePowerHP: 218,
            enginePowerKW: 160,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 95,
            batteryCapacityKWh: 54.2,
            factoryConsumptionKWh100km: 15.2,
            silhouetteKey: "mini_cooper_se_2025"
        ),
        .init(
            brand: "Opel",
            model: "Corsa Electric",
            year: 2023,
            enginePowerHP: 136,
            enginePowerKW: 100,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 100,
            batteryCapacityKWh: 50,
            factoryConsumptionKWh100km: 16.0,
            silhouetteKey: "opel_corsa_electric_2023"
        ),
        .init(
            brand: "Peugeot",
            model: "E-208",
            year: 2023,
            enginePowerHP: 156,
            enginePowerKW: 115,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 100,
            batteryCapacityKWh: 51,
            factoryConsumptionKWh100km: 15.8,
            silhouetteKey: "peugeot_e208_2023"
        ),
        .init(
            brand: "Porsche",
            model: "Taycan",
            year: 2023,
            enginePowerHP: 408,
            enginePowerKW: 300,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 270,
            batteryCapacityKWh: 93.4,
            factoryConsumptionKWh100km: 21.0,
            silhouetteKey: "porsche_taycan_2023"
        ),
        .init(
            brand: "Renault",
            model: "Zoe",
            year: 2023,
            enginePowerHP: 135,
            enginePowerKW: 100,
            acMaxChargingKW: 22,
            dcMaxChargingKW: 50,
            batteryCapacityKWh: 52,
            factoryConsumptionKWh100km: 17.6,
            silhouetteKey: "renault_zoe_2023"
        ),
        .init(
            brand: "Seat",
            model: "Mii Electric",
            year: 2020,
            enginePowerHP: 83,
            enginePowerKW: 61,
            acMaxChargingKW: 7.2,
            dcMaxChargingKW: 40,
            batteryCapacityKWh: 32.3,
            factoryConsumptionKWh100km: 14.8,
            silhouetteKey: "seat_mii_electric_2020"
        ),
        .init(
            brand: "Skywell",
            model: "ET5",
            year: 2023,
            enginePowerHP: 204,
            enginePowerKW: 150,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 80,
            batteryCapacityKWh: 72,
            factoryConsumptionKWh100km: 19.3,
            silhouetteKey: "skywell_et5_2023"
        ),
        .init(
            brand: "Volkswagen",
            model: "ID.4 Pro",
            year: 2023,
            enginePowerHP: 286,
            enginePowerKW: 210,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 135,
            batteryCapacityKWh: 77,
            factoryConsumptionKWh100km: 17.6,
            silhouetteKey: "vw_id4_2023"
        ),
        .init(
            brand: "Volvo",
            model: "EC40",
            year: 2025,
            enginePowerHP: 252,
            enginePowerKW: 185,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 205,
            batteryCapacityKWh: 82,
            factoryConsumptionKWh100km: 17.3,
            silhouetteKey: "volvo_ec40_2025"
        ),

        // Skoda
        .init(
            brand: "Skoda",
            model: "Citigo-e iV",
            year: 2020,
            enginePowerHP: 83,
            enginePowerKW: 61,
            acMaxChargingKW: 7.2,
            dcMaxChargingKW: 40,
            batteryCapacityKWh: 36.8,
            factoryConsumptionKWh100km: 14.4,
            silhouetteKey: "skoda_citigoe_2020"
        ),
        .init(
            brand: "Skoda",
            model: "Enyaq",
            trim: "80",
            year: 2023,
            enginePowerHP: 204,
            enginePowerKW: 150,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 135,
            batteryCapacityKWh: 82,
            factoryConsumptionKWh100km: 17.6,
            silhouetteKey: "skoda_enyaq80_2023"
        ),
        .init(
            brand: "Skoda",
            model: "Enyaq",
            trim: "85",
            year: 2024,
            enginePowerHP: 286,
            enginePowerKW: 210,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 135,
            batteryCapacityKWh: 82,
            factoryConsumptionKWh100km: 16.6,
            silhouetteKey: "skoda_enyaq85_2024"
        ),
        .init(
            brand: "Skoda",
            model: "Enyaq",
            trim: "85",
            year: 2025,
            enginePowerHP: 286,
            enginePowerKW: 210,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 175,
            batteryCapacityKWh: 82,
            factoryConsumptionKWh100km: 16.1,
            silhouetteKey: "skoda_enyaq85_2025"
        ),
        .init(
            brand: "Skoda",
            model: "Enyaq Coupe",
            trim: "85",
            year: 2024,
            enginePowerHP: 286,
            enginePowerKW: 210,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 135,
            batteryCapacityKWh: 82,
            factoryConsumptionKWh100km: 16.1,
            silhouetteKey: "skoda_enyaq_coupe85_2024"
        ),
        .init(
            brand: "Skoda",
            model: "Enyaq Coupe",
            trim: "85",
            year: 2025,
            enginePowerHP: 286,
            enginePowerKW: 210,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 175,
            batteryCapacityKWh: 82,
            factoryConsumptionKWh100km: 15.7,
            silhouetteKey: "skoda_enyaq_coupe85_2025"
        ),
        .init(
            brand: "Skoda",
            model: "Enyaq Coupe",
            trim: "RS",
            year: 2025,
            enginePowerHP: 340,
            enginePowerKW: 250,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 175,
            batteryCapacityKWh: 82,
            factoryConsumptionKWh100km: 17.0,
            silhouetteKey: "skoda_enyaq_coupe_rs_2025"
        ),
        .init(
            brand: "Skoda",
            model: "Elroq",
            trim: "60",
            year: 2025,
            enginePowerHP: 204,
            enginePowerKW: 150,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 165,
            batteryCapacityKWh: 63,
            factoryConsumptionKWh100km: 15.8,
            silhouetteKey: "skoda_elroq60_2025"
        ),
        .init(
            brand: "Skoda",
            model: "Elroq",
            trim: "85",
            year: 2025,
            enginePowerHP: 286,
            enginePowerKW: 210,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 175,
            batteryCapacityKWh: 82,
            factoryConsumptionKWh100km: 16.2,
            silhouetteKey: "skoda_elroq85_2025"
        ),

        // Trim bazli varyantlar
        .init(
            brand: "Tesla",
            model: "Model 3",
            trim: "Long Range AWD",
            year: 2024,
            enginePowerHP: 498,
            enginePowerKW: 366,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 250,
            batteryCapacityKWh: 79,
            factoryConsumptionKWh100km: 14.0,
            silhouetteKey: "tesla_model3_lr_awd_2024"
        ),
        .init(
            brand: "Tesla",
            model: "Model 3",
            trim: "Long Range AWD",
            year: 2025,
            enginePowerHP: 498,
            enginePowerKW: 366,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 250,
            batteryCapacityKWh: 79,
            factoryConsumptionKWh100km: 13.8,
            silhouetteKey: "tesla_model3_lr_awd_2025"
        ),
        .init(
            brand: "Tesla",
            model: "Model 3",
            trim: "Performance AWD",
            year: 2024,
            enginePowerHP: 625,
            enginePowerKW: 460,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 250,
            batteryCapacityKWh: 79,
            factoryConsumptionKWh100km: 15.5,
            silhouetteKey: "tesla_model3_performance_2024"
        ),
        .init(
            brand: "Tesla",
            model: "Model 3",
            trim: "Performance AWD",
            year: 2025,
            enginePowerHP: 625,
            enginePowerKW: 460,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 250,
            batteryCapacityKWh: 79,
            factoryConsumptionKWh100km: 15.2,
            silhouetteKey: "tesla_model3_performance_2025"
        ),
        .init(
            brand: "Tesla",
            model: "Model Y",
            trim: "RWD",
            year: 2024,
            enginePowerHP: 299,
            enginePowerKW: 220,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 175,
            batteryCapacityKWh: 60,
            factoryConsumptionKWh100km: 14.9,
            silhouetteKey: "tesla_modely_rwd_2024"
        ),
        .init(
            brand: "Tesla",
            model: "Model Y",
            trim: "RWD",
            year: 2025,
            enginePowerHP: 299,
            enginePowerKW: 220,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 175,
            batteryCapacityKWh: 60,
            factoryConsumptionKWh100km: 14.7,
            silhouetteKey: "tesla_modely_rwd_2025"
        ),
        .init(
            brand: "Tesla",
            model: "Model Y",
            trim: "Long Range AWD",
            year: 2024,
            enginePowerHP: 450,
            enginePowerKW: 331,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 250,
            batteryCapacityKWh: 75,
            factoryConsumptionKWh100km: 16.2,
            silhouetteKey: "tesla_modely_lr_awd_2024"
        ),
        .init(
            brand: "Tesla",
            model: "Model Y",
            trim: "Long Range AWD",
            year: 2025,
            enginePowerHP: 450,
            enginePowerKW: 331,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 250,
            batteryCapacityKWh: 75,
            factoryConsumptionKWh100km: 15.8,
            silhouetteKey: "tesla_modely_lr_awd_2025"
        ),
        .init(
            brand: "Tesla",
            model: "Model Y",
            trim: "Performance AWD",
            year: 2024,
            enginePowerHP: 534,
            enginePowerKW: 393,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 250,
            batteryCapacityKWh: 79,
            factoryConsumptionKWh100km: 17.4,
            silhouetteKey: "tesla_modely_performance_2024"
        ),
        .init(
            brand: "Tesla",
            model: "Model Y",
            trim: "Performance AWD",
            year: 2025,
            enginePowerHP: 534,
            enginePowerKW: 393,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 250,
            batteryCapacityKWh: 79,
            factoryConsumptionKWh100km: 17.1,
            silhouetteKey: "tesla_modely_performance_2025"
        ),
        .init(
            brand: "Hyundai",
            model: "IONIQ 5",
            trim: "Long Range AWD",
            year: 2024,
            enginePowerHP: 325,
            enginePowerKW: 239,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 233,
            batteryCapacityKWh: 84,
            factoryConsumptionKWh100km: 18.2,
            silhouetteKey: "hyundai_ioniq5_lr_awd_2024"
        ),
        .init(
            brand: "Hyundai",
            model: "IONIQ 5",
            trim: "Long Range AWD",
            year: 2025,
            enginePowerHP: 325,
            enginePowerKW: 239,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 233,
            batteryCapacityKWh: 84,
            factoryConsumptionKWh100km: 17.9,
            silhouetteKey: "hyundai_ioniq5_lr_awd_2025"
        ),
        .init(
            brand: "Hyundai",
            model: "IONIQ 5 N",
            year: 2025,
            enginePowerHP: 609,
            enginePowerKW: 448,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 260,
            batteryCapacityKWh: 84,
            factoryConsumptionKWh100km: 22.0,
            silhouetteKey: "hyundai_ioniq5_n_2025"
        ),
        .init(
            brand: "BYD",
            model: "Seal",
            trim: "Design RWD",
            year: 2024,
            enginePowerHP: 313,
            enginePowerKW: 230,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 150,
            batteryCapacityKWh: 82.5,
            factoryConsumptionKWh100km: 16.4,
            silhouetteKey: "byd_seal_design_rwd_2024"
        ),
        .init(
            brand: "BYD",
            model: "Seal",
            trim: "Design RWD",
            year: 2025,
            enginePowerHP: 313,
            enginePowerKW: 230,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 150,
            batteryCapacityKWh: 82.5,
            factoryConsumptionKWh100km: 16.1,
            silhouetteKey: "byd_seal_design_rwd_2025"
        ),
        .init(
            brand: "BYD",
            model: "Seal",
            trim: "Excellence AWD",
            year: 2024,
            enginePowerHP: 530,
            enginePowerKW: 390,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 150,
            batteryCapacityKWh: 82.5,
            factoryConsumptionKWh100km: 17.5,
            silhouetteKey: "byd_seal_excellence_awd_2024"
        ),
        .init(
            brand: "BYD",
            model: "Seal",
            trim: "Excellence AWD",
            year: 2025,
            enginePowerHP: 530,
            enginePowerKW: 390,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 150,
            batteryCapacityKWh: 82.5,
            factoryConsumptionKWh100km: 17.2,
            silhouetteKey: "byd_seal_excellence_awd_2025"
        ),
        .init(
            brand: "BMW",
            model: "iX1 xDrive30",
            year: 2024,
            enginePowerHP: 313,
            enginePowerKW: 230,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 130,
            batteryCapacityKWh: 64.7,
            factoryConsumptionKWh100km: 17.7,
            silhouetteKey: "bmw_ix1_xdrive30_2024"
        ),
        .init(
            brand: "BMW",
            model: "iX1 xDrive30",
            year: 2025,
            enginePowerHP: 313,
            enginePowerKW: 230,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 130,
            batteryCapacityKWh: 64.7,
            factoryConsumptionKWh100km: 17.3,
            silhouetteKey: "bmw_ix1_xdrive30_2025"
        ),
        .init(
            brand: "Audi",
            model: "Q4 e-tron",
            trim: "55 quattro",
            year: 2024,
            enginePowerHP: 340,
            enginePowerKW: 250,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 175,
            batteryCapacityKWh: 82,
            factoryConsumptionKWh100km: 18.8,
            silhouetteKey: "audi_q4_55_etron_2024"
        ),
        .init(
            brand: "Audi",
            model: "Q4 e-tron",
            trim: "55 quattro",
            year: 2025,
            enginePowerHP: 340,
            enginePowerKW: 250,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 175,
            batteryCapacityKWh: 82,
            factoryConsumptionKWh100km: 18.4,
            silhouetteKey: "audi_q4_55_etron_2025"
        ),
        .init(
            brand: "Mercedes",
            model: "EQE SUV",
            trim: "500 4MATIC",
            year: 2024,
            enginePowerHP: 408,
            enginePowerKW: 300,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 170,
            batteryCapacityKWh: 96,
            factoryConsumptionKWh100km: 21.0,
            silhouetteKey: "mercedes_eqe_suv_500_2024"
        ),
        .init(
            brand: "Mercedes",
            model: "EQE SUV",
            trim: "500 4MATIC",
            year: 2025,
            enginePowerHP: 408,
            enginePowerKW: 300,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 170,
            batteryCapacityKWh: 96,
            factoryConsumptionKWh100km: 20.6,
            silhouetteKey: "mercedes_eqe_suv_500_2025"
        ),
        .init(
            brand: "Volkswagen",
            model: "ID.4",
            trim: "Pure",
            year: 2024,
            enginePowerHP: 170,
            enginePowerKW: 125,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 145,
            batteryCapacityKWh: 55,
            factoryConsumptionKWh100km: 16.8,
            silhouetteKey: "vw_id4_pure_2024"
        ),
        .init(
            brand: "Volkswagen",
            model: "ID.4",
            trim: "Pure",
            year: 2025,
            enginePowerHP: 170,
            enginePowerKW: 125,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 145,
            batteryCapacityKWh: 55,
            factoryConsumptionKWh100km: 16.4,
            silhouetteKey: "vw_id4_pure_2025"
        ),
        .init(
            brand: "Volkswagen",
            model: "ID.4",
            trim: "GTX",
            year: 2024,
            enginePowerHP: 340,
            enginePowerKW: 250,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 175,
            batteryCapacityKWh: 77,
            factoryConsumptionKWh100km: 18.0,
            silhouetteKey: "vw_id4_gtx_2024"
        ),
        .init(
            brand: "Volkswagen",
            model: "ID.4",
            trim: "GTX",
            year: 2025,
            enginePowerHP: 340,
            enginePowerKW: 250,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 175,
            batteryCapacityKWh: 77,
            factoryConsumptionKWh100km: 17.6,
            silhouetteKey: "vw_id4_gtx_2025"
        ),
        .init(
            brand: "Porsche",
            model: "Macan Electric",
            trim: "Turbo",
            year: 2025,
            enginePowerHP: 639,
            enginePowerKW: 470,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 270,
            batteryCapacityKWh: 100,
            factoryConsumptionKWh100km: 20.8,
            silhouetteKey: "porsche_macan_turbo_electric_2025"
        ),
        .init(
            brand: "Skoda",
            model: "Enyaq",
            trim: "85x",
            year: 2025,
            enginePowerHP: 286,
            enginePowerKW: 210,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 175,
            batteryCapacityKWh: 82,
            factoryConsumptionKWh100km: 17.1,
            silhouetteKey: "skoda_enyaq85x_2025"
        ),
        .init(
            brand: "Skoda",
            model: "Elroq",
            trim: "50",
            year: 2025,
            enginePowerHP: 170,
            enginePowerKW: 125,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 145,
            batteryCapacityKWh: 55,
            factoryConsumptionKWh100km: 15.2,
            silhouetteKey: "skoda_elroq50_2025"
        ),
        .init(
            brand: "Cupra",
            model: "Tavascan",
            trim: "VZ",
            year: 2025,
            enginePowerHP: 340,
            enginePowerKW: 250,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 135,
            batteryCapacityKWh: 77,
            factoryConsumptionKWh100km: 18.3,
            silhouetteKey: "cupra_tavascan_vz_2025"
        ),
        .init(
            brand: "Volvo",
            model: "EX30",
            trim: "Twin Motor",
            year: 2025,
            enginePowerHP: 428,
            enginePowerKW: 315,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 153,
            batteryCapacityKWh: 69,
            factoryConsumptionKWh100km: 17.3,
            silhouetteKey: "volvo_ex30_twin_2025"
        )
    ]

    public init() {}

    public func all() -> [ReferenceVehicleSpec] {
        items
    }

    public func find(brand: String, model: String, year: Int) -> ReferenceVehicleSpec? {
        if let exactNonTrim = items.first(where: {
            $0.brand.caseInsensitiveCompare(brand) == .orderedSame &&
            $0.model.caseInsensitiveCompare(model) == .orderedSame &&
            ($0.trim?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) &&
            $0.year == year
        }) {
            return exactNonTrim
        }

        return items.first {
            $0.brand.caseInsensitiveCompare(brand) == .orderedSame &&
            $0.model.caseInsensitiveCompare(model) == .orderedSame &&
            $0.year == year
        }
    }

    public func find(brand: String, model: String, trim: String?, year: Int) -> ReferenceVehicleSpec? {
        let normalizedInputTrim = trim?.trimmingCharacters(in: .whitespacesAndNewlines)
        return items.first {
            $0.brand.caseInsensitiveCompare(brand) == .orderedSame &&
            $0.model.caseInsensitiveCompare(model) == .orderedSame &&
            $0.year == year &&
            (($0.trim?.trimmingCharacters(in: .whitespacesAndNewlines)) ?? "") ==
            (normalizedInputTrim ?? "")
        }
    }
}
