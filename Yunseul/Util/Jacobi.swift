import Foundation

/// **Jacobi 타원함수 sn, cn, dn** — 비선형 단진자의 닫힌 해 표현에 사용.
///
/// 알고리즘: Bartky 의 AGM(arithmetic-geometric mean) 하강 변환.
/// 참고: Numerical Recipes §6.11, Abramowitz & Stegun §17.6.
///
/// ```
///   a₀ = 1,  b₀ = √(1-k²),  c₀ = k
///   a_{n+1} = (a_n + b_n) / 2
///   b_{n+1} = √(a_n · b_n)
///   c_{n+1} = (a_n - b_n) / 2
///   까지 |c_n| < ε.
///   φ_n      = 2ⁿ · a_n · u
///   φ_{n-1}  = ½ (φ_n + arcsin(c_n / a_n · sin φ_n))
///   ... 까지 n = 0.
///   sn = sin φ₀,  cn = cos φ₀,  dn = √(1 − k²·sn²)
/// ```
///
/// Double 정밀에서 ~10–15 반복으로 ε ≈ 10⁻¹⁵ 수렴. **닫힌 해 (수치 적분 X)**.
///
/// - Parameters:
///   - u: 인수 (실수). `cn(u, k)` 는 주기 `4·K(k)` — 큰 u 는 호출 전에 mod 처리하면 안전.
///   - k: 모듈러스. `k ∈ [0, 1]`. k=0 이면 단순 (sin, cos, 1), k→1 이면 (tanh, sech, sech).
func jacobiSnCnDn(u: Double, k: Double) -> (sn: Double, cn: Double, dn: Double) {
    let m = k * k
    // 경계 케이스 — 수치적으로 0/1 에 너무 가까우면 극한 식으로.
    if m < 1e-15 { return (sin(u), cos(u), 1) }
    if m > 1 - 1e-15 {
        let s = tanh(u)
        let c = 1 / cosh(u)
        return (s, c, c)
    }

    // AGM 하강.
    var aArr: [Double] = [1]
    var bArr: [Double] = [sqrt(1 - m)]
    var cArr: [Double] = [k]

    let eps = 1e-12
    while abs(cArr.last!) > eps && aArr.count < 30 {
        let n = aArr.count - 1
        aArr.append((aArr[n] + bArr[n]) / 2)
        bArr.append(sqrt(aArr[n] * bArr[n]))
        cArr.append((aArr[n] - bArr[n]) / 2)
    }

    let n = aArr.count - 1
    var phi = pow(2.0, Double(n)) * aArr[n] * u

    // φ_n → φ_{n-1} → … → φ₀.
    var i = n
    while i >= 1 {
        let arg = max(-1.0, min(1.0, cArr[i] / aArr[i] * sin(phi)))
        phi = 0.5 * (phi + asin(arg))
        i -= 1
    }

    let sn = sin(phi)
    let cn = cos(phi)
    let dn = sqrt(max(0, 1 - m * sn * sn))
    return (sn, cn, dn)
}

/// 완전 타원 적분 K(k) — AGM 으로 직접 계산.
///
///   a₀ = 1, b₀ = √(1−k²),  a_{n+1} = (a_n+b_n)/2,  b_{n+1} = √(a_n b_n)
///   까지 |a−b| < ε. 그러면  K(k) = π / (2·a_∞).
func ellipticK(k: Double) -> Double {
    let m = k * k
    if m < 1e-15 { return .pi / 2 }
    if m > 1 - 1e-15 { return .infinity }
    var a = 1.0
    var b = sqrt(1 - m)
    while abs(a - b) > 1e-12 {
        let next = (a + b) / 2
        b = sqrt(a * b)
        a = next
    }
    return .pi / (2 * a)
}
