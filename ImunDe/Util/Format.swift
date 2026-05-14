import Foundation

// MARK: - 과학/공학 수치 포맷터
//
// 물리 시뮬레이션 UI 전반에서 쓸 표준 수치 표기 헬퍼. 근거:
// - ISO 80000-1 / NIST SP 811: 단위 기호 앞에 thin space (U+2009),
//   복합 단위는 중점(·) 또는 슬래시.
// - KS A ISO 80000: 한국 SI 표기 — 위와 동일.
// - 교과서 컨벤션: 측정값은 유효숫자, 계산 결과는 정밀도에 맞춰. 5자리
//   고정 소수는 "물리 학습자 vs 측정 도구" 구분이 모호해 권장하지 않음.

enum SciFormat {

    /// Thin space (U+2009) — SI 표준 단위 기호 구분자.
    static let thinSpace = "\u{2009}"

    /// 유효숫자 기반 포맷. 학습 단계에서 권장되는 3 유효숫자가 기본.
    /// - 0 처리: 정확히 0 일 때 `"0"` 반환 (`%.3g` 가 `0.00`로 찍는 것 방지).
    /// - 매우 작거나 큰 값(10^4 이상, 10^-2 이하)은 자동으로 공학 표기로.
    static func sigFig(_ value: Double, digits: Int = 3) -> String {
        guard value.isFinite else { return "—" }
        if value == 0 { return "0" }
        let av = abs(value)
        if av >= 1e4 || av < 1e-2 {
            return engineering(value, digits: digits)
        }
        // %.Ng 의 N 은 유효숫자, 0 패딩 없음 — 교과서 표기와 일치.
        let s = String(format: "%.\(digits)g", value)
        return s
    }

    /// 공학 표기 — 지수가 3의 배수. SI 접두사로 자동 변환 (k/M/μ/m 등).
    /// - 지수가 SI 접두사 범위(10^-12 ~ 10^12)를 벗어나면 `×10^n` 형태로.
    static func engineering(_ value: Double, digits: Int = 3) -> String {
        guard value.isFinite, value != 0 else {
            return value == 0 ? "0" : "—"
        }
        let sign = value < 0 ? "-" : ""
        let av = abs(value)
        let exp = Int(floor(log10(av)))
        let engExp = Int((Double(exp) / 3.0).rounded(.down)) * 3
        let mantissa = av / pow(10, Double(engExp))
        let mantissaStr = String(format: "%.\(max(0, digits - 1))f", mantissa)
        if let prefix = siPrefix[engExp] {
            return "\(sign)\(mantissaStr)\(thinSpace)\(prefix)"
        }
        // 접두사 범위 밖 — ×10^n 표기. 첨자 형태는 호출 측이 처리.
        return "\(sign)\(mantissaStr)×10^\(engExp)"
    }

    /// 단위 부착 — `value` + thin space + `unit`. unit 은 SI 기호 그대로
    /// (예: "m", "m/s", "kg·m/s²"). 공학 표기인 경우 접두사가 이미 mantissa
    /// 측에 붙어 있어 unit 만 덧붙임 (예: "1.23 kN").
    ///
    /// Note: engineering 표기 결과는 이미 SI 접두사를 포함하므로 unit 의
    /// 첫 글자가 그대로 따라옴 — "1.23 km" 와 같이 자연스러운 결합.
    static func withUnit(_ value: Double, unit: String, digits: Int = 3) -> String {
        let num = sigFig(value, digits: digits)
        if num == "—" || num == "0" { return "\(num)\(thinSpace)\(unit)" }
        // engineering() 결과에 이미 SI 접두사가 thin-space 와 함께 붙어
        // 있다면 unit 만 추가 (공백 없이) — "1.23 km" 형태.
        if num.contains(thinSpace) {
            return "\(num)\(unit)"
        }
        return "\(num)\(thinSpace)\(unit)"
    }

    /// SI 접두사 매핑 — 1e-12 (p) ~ 1e12 (T). 학습 도구 권장 범위.
    private static let siPrefix: [Int: String] = [
        -12: "p", -9: "n", -6: "μ", -3: "m",
        0: "",
        3: "k", 6: "M", 9: "G", 12: "T",
    ]

    /// 고정 소수 포맷 — `%.Nf`. 단위가 자동 변환되지 않는 일부 컨텍스트
    /// (좌표, 각도) 에서만 사용. 일반 측정값은 `sigFig` 사용.
    static func fixed(_ value: Double, places: Int = 2) -> String {
        guard value.isFinite else { return "—" }
        return String(format: "%.\(places)f", value)
    }

    /// 각도 — degree 기호 (°) 부착. 기본 1자리 소수.
    static func degrees(_ value: Double, places: Int = 1) -> String {
        guard value.isFinite else { return "—" }
        return "\(String(format: "%+.\(places)f", value))°"
    }
}
