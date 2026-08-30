import SwiftUI

public struct AddChargeScreen: View {
    private enum PostSaveAction {
        case none
        case showAnalysis
    }

    private enum Layout {
        static let blockSpacing: CGFloat = CGFloat(UIConstants.defaultSectionSpacing)
        static let cardCornerRadius: CGFloat = CGFloat(UIConstants.cardCornerRadius)
        static let methodCardHeight: CGFloat = 82
        static let summaryRowSpacing: CGFloat = 10
        static let saveButtonHeight: CGFloat = 54
        static let footerPadding: CGFloat = 16
    }

    @StateObject private var viewModel: AddChargeViewModel
    @State private var showSavedFeedback = false
    @State private var isSaving = false
    @State private var savedSessionScore: ChargeSessionScoreReport?
    @State private var savedPlanFeedbackMessage: String?
    @State private var savedRealtimeMetricsUpdate: ChargeMetricsRealtimeUpdate?
    @State private var showingFirstChargeSuccessSheet = false
    @State private var showingOperatorPicker = false
    @State private var showingLocationPicker = false
    @State private var postSaveAction: PostSaveAction = .none
    @State private var showOptionalChargeFields = false
    @State private var showOptionalVehicleFields = false

    private let demoBannerText: String?
    private let isDemoMode: Bool
    private let onSaved: () -> Void
    private let onShowAnalysis: (() -> Void)?

    public init(
        viewModel: AddChargeViewModel,
        demoBannerText: String? = nil,
        isDemoMode: Bool = false,
        onSaved: @escaping () -> Void,
        onShowAnalysis: (() -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.demoBannerText = demoBannerText
        self.isDemoMode = isDemoMode
        self.onSaved = onSaved
        self.onShowAnalysis = onShowAnalysis
    }

    public var body: some View {
        Form {
            if viewModel.activeVehicle == nil && !viewModel.isEditing {
                Section {
                    ContentUnavailableView(
                        "Aktif arac bulunamadi",
                        systemImage: "car.circle",
                        description: Text("Ayarlar > Arac Yonetimi adimindan once bir araci aktif hale getir.")
                    )
                }
            }

            if let predictiveDefaults = viewModel.predictiveDefaults,
               !predictiveDefaults.quickPresets.isEmpty {
                Section("Akıllı Hızlı Giriş") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(predictiveDefaults.quickPresets) { preset in
                                predictivePresetCard(preset)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section("Yöntem") {
                methodSelectorBlock
            }

            Section("Lokasyon") {
                locationFieldsBlock
            }

            Section("Batarya") {
                VStack(alignment: .leading, spacing: Layout.blockSpacing) {
                    if viewModel.isPastDatedEntry {
                        Toggle(
                            "Şarj yüzdesi eklemek istiyorum (opsiyonel)",
                            isOn: Binding(
                                get: { viewModel.includeSOCForPastDate },
                                set: { viewModel.setIncludeSOCForPastDate($0) }
                            )
                        )
                        .tint(AppTheme.publicACColor)
                    }

                    if viewModel.shouldShowSOCSelection {
                        batterySummary
                        BatterySOCView(startSOC: viewModel.socStart, endSOC: viewModel.socEnd)

                        batterySlider(
                            title: "Başlangıç",
                            valueText: "%\(Int(viewModel.socStart))",
                            value: $viewModel.socStart,
                            range: 0...100,
                            tint: AppTheme.publicACColor
                        )

                        batterySlider(
                            title: "Bitiş",
                            valueText: "%\(Int(viewModel.socEnd))",
                            value: $viewModel.socEnd,
                            range: viewModel.socStart...100,
                            tint: AppTheme.homeColor
                        )

                        quickTargetSelection
                    } else {
                        Text(viewModel.socHintText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Zorunlu Alanlar") {
                TextField("Toplam tutar (\(viewModel.priceCurrencyCode))", text: $viewModel.totalPrice)
                    .voltlyDecimalKeyboard()
                validationHint(viewModel.totalPriceValidationMessage)
            }

            Section {
                Button {
                    withAnimation { showOptionalChargeFields.toggle() }
                } label: {
                    HStack {
                        Text("Detaylı şarj verisi ekle")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: showOptionalChargeFields ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                if showOptionalChargeFields {
                    TextField("Tarife ücreti (\(viewModel.priceCurrencyCode)/kWh)", text: $viewModel.tariffPricePerKWh)
                        .voltlyDecimalKeyboard()
                        .onChange(of: viewModel.tariffPricePerKWh) { _, _ in
                            viewModel.onTariffInputChanged()
                        }
                    validationHint(viewModel.tariffValidationMessage)

                    TextField("Enerji (kWh)", text: $viewModel.energyInput)
                        .voltlyDecimalKeyboard()
                    validationHint(viewModel.energyValidationMessage)
                    warningHint(viewModel.energyPriceConsistencyWarningMessage)

                    TextField("Süre (dakika)", text: $viewModel.durationMin)
                        .voltlyNumberKeyboard()
                    validationHint(viewModel.durationValidationMessage)
                    warningHint(viewModel.chargeSpeedValidationMessage)
                }
            }

            Section("Bağlam") {
                contextTagsBlock
            }

            Section {
                Button {
                    withAnimation { showOptionalVehicleFields.toggle() }
                } label: {
                    HStack {
                        Text("Araç & çevre verisi ekle")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: showOptionalVehicleFields ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                if showOptionalVehicleFields {
                    TextField("Odometre (km)", text: $viewModel.odometerKM)
                        .voltlyDecimalKeyboard()
                    validationHint(viewModel.odometerValidationMessage)

                    TextField("Dış sıcaklık (°C)", text: $viewModel.outsideTempC)
                        .voltlyDecimalKeyboard()
                    validationHint(viewModel.temperatureValidationMessage)

                    TextField("Özel not", text: $viewModel.notes)
                }
            }

            Section("Seans") {
                DatePicker(
                    "Tarih",
                    selection: Binding(
                        get: { viewModel.sessionDate },
                        set: { viewModel.setSessionDate($0) }
                    ),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .environment(\.locale, Locale.autoupdatingCurrent)
            }

            Section("Bu şarjın özeti") {
                summaryCard
            }

            if let message = viewModel.message {
                Section {
                    Text(message)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(viewModel.isEditing ? "Sarj Duzenle" : "Sarj Ekle")
        .onAppear {
            viewModel.refreshChargingDefaults()
            viewModel.refreshLiveInsightNow()
            let hasChargeDetail = !viewModel.tariffPricePerKWh.isEmpty
                || !viewModel.energyInput.isEmpty
                || !viewModel.durationMin.isEmpty
            let hasVehicleDetail = !viewModel.odometerKM.isEmpty
                || !viewModel.outsideTempC.isEmpty
                || !viewModel.notes.isEmpty
            if hasChargeDetail { showOptionalChargeFields = true }
            if hasVehicleDetail { showOptionalVehicleFields = true }
        }
        .scrollDismissesKeyboard(.immediately)
        .onChange(of: viewModel.draftSignature) { _, _ in
            viewModel.persistDraft()
            viewModel.scheduleLiveInsightRefresh()
        }
        .onDisappear {
            viewModel.persistDraft()
        }
        .safeAreaInset(edge: .bottom) {
            saveActionBar
        }
        .sheet(isPresented: $showingFirstChargeSuccessSheet, onDismiss: handleFirstChargeSheetDismissed) {
            FirstChargeSuccessSheet(
                onContinue: {
                    postSaveAction = .none
                    showingFirstChargeSuccessSheet = false
                },
                onShowAnalysis: onShowAnalysis.map { _ in
                    {
                        postSaveAction = .showAnalysis
                        showingFirstChargeSuccessSheet = false
                    }
                }
            )
            .presentationDetents([.height(300), .medium])
        }
        .sheet(isPresented: $showingOperatorPicker) {
            OperatorPickerSheet(
                selectedOperator: viewModel.stationBrand,
                favoriteOperators: viewModel.favoriteOperators,
                otherOperators: viewModel.otherOperators,
                isFavorite: { viewModel.isOperatorFavorite($0) },
                onSelect: { viewModel.selectOperator($0) },
                onToggleFavorite: { viewModel.toggleFavoriteOperator($0) },
                onClearSelection: { viewModel.clearSelectedOperator() }
            )
        }
        .sheet(isPresented: $showingLocationPicker) {
            LocationPickerSheet(
                selectedLocation: viewModel.locationName,
                locations: viewModel.locationCatalog,
                onSelect: { viewModel.selectLocation($0) },
                onClearSelection: { viewModel.clearSelectedLocation() }
            )
        }
        .overlay(alignment: .top) {
            VStack(spacing: 8) {
                if let demoBannerText {
                    Label(demoBannerText, systemImage: "sparkles.rectangle.stack.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(AppTheme.homeColor.opacity(0.96))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if showSavedFeedback {
                    savedFeedbackView
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.top, 12)
        }
    }

    private var isSaveDisabled: Bool {
        !viewModel.canSave || isSaving
    }

    private var saveActionTitle: String {
        if isDemoMode {
            return "Demo Olarak Dene"
        }
        return viewModel.isEditing ? "Kaydı Güncelle" : "Kaydı Kaydet"
    }

    private var saveActionBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: performSave) {
                HStack(spacing: 10) {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    Text(isSaving ? "Kaydediliyor..." : saveActionTitle)
                        .font(.headline.weight(.semibold))
                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: Layout.saveButtonHeight)
                .padding(.horizontal, 14)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
                    .fill(isSaveDisabled ? Color.secondary.opacity(0.35) : AppTheme.publicACColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
                    .stroke(isSaveDisabled ? Color.clear : AppTheme.publicACColor.opacity(0.35), lineWidth: 1)
            )
            .shadow(
                color: isSaveDisabled ? .clear : AppTheme.publicACColor.opacity(0.28),
                radius: isSaveDisabled ? 0 : UIConstants.cardShadowRadius,
                x: 0,
                y: 2
            )
            .disabled(isSaveDisabled)

            if isSaveDisabled && !isSaving {
                Text("Kaydetmek için en az toplam tutarı gir ve hataları düzelt.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, Layout.footerPadding)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
    }

    private var methodSelectorBlock: some View {
        HStack(spacing: 10) {
            ForEach(ChargeMethod.allCases) { method in
                methodOptionCard(for: method)
            }
        }
    }

    private var locationFieldsBlock: some View {
        VStack(alignment: .leading, spacing: Layout.blockSpacing) {
            if isHomeMethod, viewModel.availableHomeProfiles.count > 1 {
                Picker(
                    "Ev profili",
                    selection: Binding(
                        get: { viewModel.selectedHomeProfileID },
                        set: { viewModel.selectHomeProfile(id: $0) }
                    )
                ) {
                    ForEach(viewModel.availableHomeProfiles) { profile in
                        Text(profile.displayName).tag(profile.id)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(stationFieldTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if isHomeMethod {
                    TextField(stationFieldPlaceholder, text: $viewModel.stationBrand)
                        .onChange(of: viewModel.stationBrand) { _, _ in
                            viewModel.onStationBrandChanged()
                        }
                } else {
                    operatorDropdownField
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(locationFieldTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if isHomeMethod {
                    TextField(locationFieldPlaceholder, text: $viewModel.locationName)
                        .onChange(of: viewModel.locationName) { _, _ in
                            viewModel.onLocationNameChanged()
                        }
                } else {
                    locationDropdownField
                }
            }

            if !isHomeMethod {
                Text("İstasyon/şube adı ve konumu birlikte girebilirsin.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !isHomeMethod, viewModel.hasSmartFavoriteStationSuggestions {
                smartFavoriteStationSuggestionsBlock
            }
        }
    }

    private var operatorDropdownField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                showingOperatorPicker = true
            } label: {
                HStack(spacing: 10) {
                    Text(viewModel.stationBrand.isEmpty ? stationFieldPlaceholder : viewModel.stationBrand)
                        .foregroundStyle(viewModel.stationBrand.isEmpty ? .secondary : .primary)
                    Spacer()
                    if !viewModel.stationBrand.isEmpty, viewModel.isOperatorFavorite(viewModel.stationBrand) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                    }
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if !viewModel.stationBrand.isEmpty {
                Button {
                    viewModel.toggleFavoriteOperator(viewModel.stationBrand)
                } label: {
                    Label(
                        viewModel.isOperatorFavorite(viewModel.stationBrand) ? "Favorilerden çıkar" : "Favorilere ekle",
                        systemImage: viewModel.isOperatorFavorite(viewModel.stationBrand) ? "star.slash" : "star"
                    )
                    .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var locationDropdownField: some View {
        Button {
            showingLocationPicker = true
        } label: {
            HStack(spacing: 10) {
                Text(viewModel.locationName.isEmpty ? locationFieldPlaceholder : viewModel.locationName)
                    .foregroundStyle(viewModel.locationName.isEmpty ? .secondary : .primary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var smartFavoriteStationSuggestionsBlock: some View {
        if let report = viewModel.smartFavoriteStations,
           !report.suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Akıllı istasyon önerileri")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(report.suggestions) { suggestion in
                    Button {
                        Haptics.selection()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.applySmartFavoriteStation(suggestion)
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: smartFavoriteIcon(for: suggestion.category))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(smartFavoriteTint(for: suggestion.category))
                                .frame(width: 18, height: 18)
                                .padding(7)
                                .background(smartFavoriteTint(for: suggestion.category).opacity(0.14))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(suggestion.category.titleTR)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(smartFavoriteTint(for: suggestion.category))
                                    Text(suggestion.suggestedChargeMethod.titleTR)
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(suggestion.suggestedChargeMethod.uiColor.opacity(0.15))
                                        .foregroundStyle(suggestion.suggestedChargeMethod.uiColor)
                                        .clipShape(Capsule())
                                    if let brand = suggestion.stationBrand,
                                       !brand.isEmpty,
                                       viewModel.isOperatorFavorite(brand) {
                                        Image(systemName: "star.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.yellow)
                                    }
                                }

                                Text(suggestion.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)

                                Text(smartFavoriteDetailText(for: suggestion))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }

                            Spacer(minLength: 6)

                            Image(systemName: "arrow.up.right.circle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.overlaySurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var batterySummary: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Şarj Yüzdesi")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("%\(Int(viewModel.socStart)) → %\(Int(viewModel.socEnd))")
                    .font(.headline.weight(.semibold))
            }
            Spacer()
            Text("+%\(max(0, Int(viewModel.socEnd - viewModel.socStart)))")
                .font(.subheadline.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppTheme.publicACColor.opacity(0.18))
                .foregroundStyle(AppTheme.publicACColor)
                .clipShape(Capsule())
        }
        .padding(12)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cardCornerRadius))
    }

    private var quickTargetSelection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hızlı bitiş seçimi")
                .font(.subheadline.weight(.semibold))
            Text("Sadece bitiş yüzdesini değiştirir")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                quickTargetButton(80)
                quickTargetButton(90)
                quickTargetButton(100)
            }

            validationHint(viewModel.socValidationMessage)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Anlık hesaplama")
                .font(.subheadline.weight(.semibold))

            VStack(spacing: Layout.summaryRowSpacing) {
                summaryRow(
                    title: "Eklenen enerji",
                    value: viewModel.selectedEnergyKWh.map(NumberFormatting.kWh),
                    fallback: viewModel.energySummaryFallback,
                    showsEstimatedBadge: viewModel.energyIsEstimated && viewModel.selectedEnergyKWh != nil
                )

                summaryRow(
                    title: "Tahmini toplam / tarifeden toplam",
                    value: (
                        viewModel.estimatedPriceFromTariff.map { NumberFormatting.currency($0, code: viewModel.priceCurrencyCode) } ??
                        viewModel.enteredTotalPrice.map { NumberFormatting.currency($0, code: viewModel.priceCurrencyCode) }
                    ),
                    fallback: viewModel.totalSummaryFallback
                )

                summaryRow(
                    title: "TL/kWh",
                    value: viewModel.estimatedTLPerKWh.map { NumberFormatting.tlPerKWh($0, currencyCode: viewModel.priceCurrencyCode) },
                    fallback: viewModel.tlPerKWhSummaryFallback
                )

                summaryRow(
                    title: "Ortalama şarj hızı",
                    value: viewModel.estimatedChargeSpeedKW.map { "\(NumberFormatting.oneDecimal($0)) kW" },
                    fallback: viewModel.speedSummaryFallback
                )
                warningHint(viewModel.chargeSpeedValidationMessage)

                summaryRow(
                    title: "Menzil kazancı",
                    value: viewModel.estimatedRangeGain.map(NumberFormatting.km),
                    fallback: viewModel.rangeSummaryFallback
                )
            }

            if let liveInsight = viewModel.liveInsight {
                Divider()
                liveInsightPanel(liveInsight)
            }
        }
        .padding(12)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cardCornerRadius))
    }

    private var contextTagsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("İstersen bu seansın koşulunu etiketle. Analizler bu bağlamı kullanır.")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                ForEach(ChargeContextTag.allCases) { tag in
                    contextTagButton(tag)
                }
            }
        }
    }

    private func liveInsightPanel(_ insight: ChargeFormLiveInsight) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "waveform.path.ecg.text")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(viewModel.chargeMethod.uiColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Canlı insight")
                        .font(.subheadline.weight(.semibold))
                    Text(insight.methodDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                liveInsightMetricTile(
                    title: "Tahmini TL/kWh",
                    value: insight.tlPerKWh.value.map { NumberFormatting.tlPerKWh($0, currencyCode: viewModel.priceCurrencyCode) },
                    fallback: "Fiyat ve enerjiyle hesaplanır",
                    confidence: insight.tlPerKWh.confidence
                )

                liveInsightMetricTile(
                    title: "Tahmini TL/100 km",
                    value: insight.tlPer100Km.value.map { NumberFormatting.currency($0, code: viewModel.priceCurrencyCode) },
                    fallback: "Yeterli veri yok",
                    confidence: insight.tlPer100Km.confidence
                )
            }

            liveInsightMessageRow(
                title: insight.pricePosition.title,
                detail: insight.pricePosition.detail,
                systemImage: pricePositionIcon(for: insight.pricePosition.kind),
                tint: pricePositionColor(for: insight.pricePosition.kind)
            )

            liveInsightMessageRow(
                title: "Alışkanlık yorumu",
                detail: insight.habitComment,
                systemImage: "chart.line.uptrend.xyaxis",
                tint: AppTheme.publicACColor
            )

            if let alternativeSuggestion = insight.alternativeSuggestion {
                liveInsightMessageRow(
                    title: "\(alternativeSuggestion.recommendedMethod.titleTR) önerisi",
                    detail: alternativeSuggestion.reason,
                    systemImage: alternativeSuggestion.recommendedMethod.iconName,
                    tint: AppTheme.publicDCColor,
                    emphasized: true
                )
            }
        }
    }

    private func liveInsightMetricTile(
        title: String,
        value: String?,
        fallback: String,
        confidence: DataConfidenceScore
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if confidence.source == .estimated || confidence.source == .mixed {
                    EstimationBadge(isEstimated: true)
                }
            }

            Text(value ?? "--")
                .font(.headline.weight(.semibold))

            if value == nil {
                Text(fallback)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AppTheme.overlaySurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func liveInsightMessageRow(
        title: String,
        detail: String,
        systemImage: String,
        tint: Color,
        emphasized: Bool = false
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 20, height: 20)
                .padding(6)
                .background(tint.opacity(emphasized ? 0.18 : 0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(emphasized ? tint : .primary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func pricePositionColor(for kind: ChargeFormPricePositionKind) -> Color {
        switch kind {
        case .cheaper:
            return AppTheme.homeColor
        case .neutral:
            return AppTheme.publicACColor
        case .expensive:
            return AppTheme.publicDCColor
        case .unavailable:
            return .secondary
        }
    }

    private func pricePositionIcon(for kind: ChargeFormPricePositionKind) -> String {
        switch kind {
        case .cheaper:
            return "arrow.down.circle.fill"
        case .neutral:
            return "equal.circle.fill"
        case .expensive:
            return "arrow.up.circle.fill"
        case .unavailable:
            return "questionmark.circle.fill"
        }
    }

    private func contextTagButton(_ tag: ChargeContextTag) -> some View {
        let isSelected = viewModel.hasContextTag(tag)
        let tint = contextTagColor(for: tag)

        return Button {
            Haptics.selection()
            withAnimation(.easeInOut(duration: 0.16)) {
                viewModel.toggleContextTag(tag)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: contextTagIcon(for: tag))
                    .font(.caption.weight(.semibold))
                Text(tag.titleTR)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? tint.opacity(0.16) : AppTheme.surface)
            .foregroundStyle(isSelected ? tint : .primary)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? tint.opacity(0.5) : Color.secondary.opacity(0.18), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func smartFavoriteDetailText(for suggestion: SmartFavoriteStationSuggestion) -> String {
        switch suggestion.category {
        case .mostUsed:
            return "\(suggestion.sessionCount) seansla en sık kullandığın istasyon."
        case .cheapest:
            if let averageTLPerKWh = suggestion.averageTLPerKWh {
                return "Ortalama \(NumberFormatting.tlPerKWh(averageTLPerKWh, currencyCode: viewModel.priceCurrencyCode))."
            }
            return "Maliyet karşılaştırması için öne çıkan istasyon."
        case .mostEfficient:
            if let averageTLPer100Km = suggestion.averageTLPer100Km {
                return "Yaklaşık \(NumberFormatting.currency(averageTLPer100Km, code: viewModel.priceCurrencyCode)) / 100 km."
            }
            if let averageEnergyPer100Km = suggestion.averageEnergyPer100Km {
                return "Yaklaşık \(NumberFormatting.oneDecimal(averageEnergyPer100Km)) kWh / 100 km."
            }
            return "Verim tarafında öne çıkan istasyon."
        }
    }

    private func smartFavoriteTint(for category: SmartFavoriteStationCategory) -> Color {
        switch category {
        case .mostUsed:
            return AppTheme.publicACColor
        case .cheapest:
            return AppTheme.homeColor
        case .mostEfficient:
            return AppTheme.publicDCColor
        }
    }

    private func smartFavoriteIcon(for category: SmartFavoriteStationCategory) -> String {
        switch category {
        case .mostUsed:
            return "clock.badge.checkmark"
        case .cheapest:
            return "banknote"
        case .mostEfficient:
            return "leaf"
        }
    }

    private func predictivePresetCard(_ preset: QuickChargePreset) -> some View {
        let tint = presetColor(for: preset.kind)

        return Button {
            Haptics.selection()
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.applyQuickPreset(preset)
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Image(systemName: presetIcon(for: preset.kind))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(tint)
                        .frame(width: 32, height: 32)
                        .background(tint.opacity(0.14))
                        .clipShape(Circle())

                    Spacer(minLength: 8)

                    Text(preset.prefill.chargeMethod.titleTR)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(tint.opacity(0.14))
                        .foregroundStyle(tint)
                        .clipShape(Capsule())
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.title)
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.leading)
                    Text(preset.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Text(preset.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)

                Text("Uygula")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 220, alignment: .leading)
            .frame(minHeight: 168, alignment: .leading)
            .padding(12)
            .background(AppTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(tint.opacity(0.24), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private func presetColor(for kind: QuickChargePresetKind) -> Color {
        switch kind {
        case .homeRoutine:
            return AppTheme.homeColor
        case .publicACFavorite:
            return AppTheme.publicACColor
        case .roadTripDC:
            return AppTheme.publicDCColor
        }
    }

    private func presetIcon(for kind: QuickChargePresetKind) -> String {
        switch kind {
        case .homeRoutine:
            return "house.fill"
        case .publicACFavorite:
            return "bolt"
        case .roadTripDC:
            return "bolt.car.fill"
        }
    }

    private func contextTagColor(for tag: ChargeContextTag) -> Color {
        switch tag {
        case .longRoad:
            return AppTheme.publicDCColor
        case .cityDriving:
            return AppTheme.publicACColor
        case .coldWeather:
            return .blue
        case .hotWeather:
            return .orange
        case .heavyTraffic:
            return .yellow
        case .other:
            return AppTheme.homeColor
        }
    }

    private func contextTagIcon(for tag: ChargeContextTag) -> String {
        switch tag {
        case .longRoad:
            return "road.lanes"
        case .cityDriving:
            return "building.2.fill"
        case .coldWeather:
            return "snowflake"
        case .hotWeather:
            return "sun.max.fill"
        case .heavyTraffic:
            return "car.2.fill"
        case .other:
            return "tag.fill"
        }
    }

    private func summaryRow(
        title: String,
        value: String?,
        fallback: String,
        showsEstimatedBadge: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let value {
                    Text(value)
                        .font(.subheadline.weight(.semibold))
                    if showsEstimatedBadge {
                        EstimationBadge(isEstimated: true)
                    }
                } else {
                    Text("Hesaplanamadı")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            if value == nil {
                Text(fallback)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func validationHint(_ message: String?) -> some View {
        if let message {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 2)
        }
    }

    @ViewBuilder
    private func warningHint(_ message: String?) -> some View {
        if let message {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 2)
        }
    }

    private func methodOptionCard(for method: ChargeMethod) -> some View {
        let isSelected = viewModel.chargeMethod == method
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                viewModel.setChargeMethod(method)
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: methodIcon(for: method))
                    Text(method.titleTR)
                }
                .font(.subheadline.weight(.semibold))

                Text(methodSubtitle(for: method))
                    .font(.caption)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: Layout.methodCardHeight, alignment: .leading)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
                    .fill(isSelected ? method.uiColor.opacity(0.20) : AppTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
                    .stroke(isSelected ? method.uiColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 1.5 : 1)
            )
            .foregroundStyle(isSelected ? method.uiColor : .primary)
        }
        .buttonStyle(.plain)
    }

    private func batterySlider(
        title: String,
        valueText: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(valueText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
            }
            Slider(value: value, in: range, step: 1)
                .tint(tint)
                .onChange(of: Int(value.wrappedValue.rounded())) { oldValue, newValue in
                    guard oldValue != newValue else { return }
                    Haptics.selection()
                }
        }
    }

    private func quickTargetButton(_ value: Double) -> some View {
        let isSelected = Int(viewModel.socEnd.rounded()) == Int(value)
        return Button("%\(Int(value))") {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                viewModel.setTargetSOC(value)
            }
            Haptics.selection()
        }
        .font(.subheadline.weight(.semibold))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? AppTheme.publicDCColor : AppTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? AppTheme.publicDCColor : Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .foregroundStyle(isSelected ? .white : .primary)
        .buttonStyle(.plain)
    }

    private func performSave() {
        guard !isSaveDisabled else { return }
        Haptics.softImpact()
        isSaving = true
        showSavedFeedback = false
        savedSessionScore = nil
        savedPlanFeedbackMessage = nil
        savedRealtimeMetricsUpdate = nil
        if isDemoMode {
            Haptics.success()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                showSavedFeedback = true
            }
            Task {
                try? await Task.sleep(nanoseconds: 1_100_000_000)
                await MainActor.run {
                    isSaving = false
                }
            }
            return
        }
        switch viewModel.save() {
        case .success(let payload):
            Haptics.success()
            savedSessionScore = payload.sessionScore
            savedPlanFeedbackMessage = payload.planFeedbackMessage
            savedRealtimeMetricsUpdate = payload.realtimeMetricsUpdate
            if payload.showFirstChargeCelebration {
                isSaving = false
                postSaveAction = .none
                showingFirstChargeSuccessSheet = true
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showSavedFeedback = true
                }

                Task {
                    try? await Task.sleep(nanoseconds: 650_000_000)
                    onSaved()
                    isSaving = false
                }
            }
        case .failure:
            isSaving = false
        }
    }

    private var savedFeedbackTitle: String {
        if isDemoMode {
            return "Demo kaydı eklendi"
        }
        if let savedSessionScore {
            return ChargeSessionScoringText.postSaveTitle(for: savedSessionScore)
        }
        return viewModel.isEditing ? "Kayıt güncellendi" : "Kayıt eklendi"
    }

    private var savedFeedbackTint: Color {
        isDemoMode ? AppTheme.homeColor : AppTheme.publicACColor
    }

    private var savedFeedbackSystemImage: String {
        isDemoMode ? "eye.circle.fill" : "bolt.circle.fill"
    }

    private var savedFeedbackView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: savedFeedbackSystemImage)
                    .font(.subheadline.weight(.bold))
                Text(savedFeedbackTitle)
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
                if let savedSessionScore, !isDemoMode {
                    ChargeSessionScoreBadge(report: savedSessionScore)
                }
            }

            Text(savedFeedbackMessage)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(2)

            if let basisLabel = savedRealtimeMetricsUpdate?.latestBlock?.calculationBasis,
               !basisLabel.isEmpty {
                Text(basisLabel)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(savedFeedbackTint.opacity(0.95))
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }

    private var savedFeedbackMessage: String {
        if isDemoMode {
            return "Bu kayıt yalnızca demo akışı için gösterildi."
        }
        if let update = savedRealtimeMetricsUpdate,
           let snapshot = update.snapshots[.last30Days] {
            let metricText = makeSavedMetricsSummary(snapshot: snapshot)
            if let savedPlanFeedbackMessage {
                return "\(savedPlanFeedbackMessage) \(metricText)"
            }
            if let savedSessionScore {
                return "\(ChargeSessionScoringText.postSaveMessage(for: savedSessionScore)) \(metricText)"
            }
            return metricText
        }
        guard let savedSessionScore else {
            return savedPlanFeedbackMessage ?? "Kayıt analizlere eklendi."
        }
        return savedPlanFeedbackMessage ?? ChargeSessionScoringText.postSaveMessage(for: savedSessionScore)
    }

    private func makeSavedMetricsSummary(snapshot: VehicleMetricSnapshot) -> String {
        let tryText = snapshot.avgTRY100Km.map { "TRY/100 km: \(Int($0.rounded()))" } ?? nil
        let consumptionText = snapshot.avgKWh100Km.map { String(format: "Tuketim: %.1f kWh/100 km", $0) }
        let savingsText = snapshot.savingPercent.map { "Benzine gore %\(Int($0.rounded()))" }
        return [tryText, consumptionText, savingsText]
            .compactMap { $0 }
            .joined(separator: " • ")
    }

    private func handleFirstChargeSheetDismissed() {
        let action = postSaveAction
        postSaveAction = .none
        onSaved()
        if action == .showAnalysis {
            onShowAnalysis?()
        }
    }

    private var isHomeMethod: Bool {
        viewModel.chargeMethod == .home
    }

    private var stationFieldTitle: String {
        isHomeMethod ? "Şarj noktası adı" : "Operatör / İstasyon markası"
    }

    private var stationFieldPlaceholder: String {
        isHomeMethod ? "Örn. Ev wallbox" : "Örn. ZES, Eşarj, Trugo"
    }

    private var locationFieldTitle: String {
        isHomeMethod ? "Konum" : "İstasyon / Şube ve Konum"
    }

    private var locationFieldPlaceholder: String {
        isHomeMethod ? "Örn. Ev garajı / iş yeri" : "Örn. Zorlu AVM Otopark - B2"
    }

    private func methodSubtitle(for method: ChargeMethod) -> String {
        switch method {
        case .home:
            return "Priz / wallbox"
        case .publicAC:
            return "Yavaş / orta hız"
        case .publicDC:
            return "Hızlı şarj"
        }
    }

    private func methodIcon(for method: ChargeMethod) -> String {
        switch method {
        case .home:
            return "house.fill"
        case .publicAC:
            return "bolt.circle"
        case .publicDC:
            return "bolt.circle.fill"
        }
    }
}

#if DEBUG
@MainActor
struct AddChargeScreen_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationStack {
                AddChargeScreen(viewModel: previewViewModel(method: .home)) {}
            }
            .previewDisplayName("Ev Şarjı")

            NavigationStack {
                AddChargeScreen(viewModel: previewViewModel(method: .publicDC)) {}
            }
            .previewDisplayName("DC Şarj")
        }
    }

    private static func previewViewModel(method: ChargeMethod) -> AddChargeViewModel {
        let environment = try! AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )
        try? environment.createVehicleUseCase.execute(vehicle)
        try? environment.setActiveVehicleUseCase.execute(id: vehicle.id)

        let viewModel = AddChargeViewModel(environment: environment)
        viewModel.setChargeMethod(method)
        viewModel.totalPrice = "420"
        viewModel.energyInput = "32"
        viewModel.durationMin = "40"
        viewModel.stationBrand = method == .home ? "Ev wallbox" : "ZES"
        viewModel.locationName = method == .home ? "Ev garajı" : "Levent"
        return viewModel
    }
}
#endif
