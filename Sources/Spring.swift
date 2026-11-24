import Foundation

struct Spring {
    var x: Double = 0
    var v: Double = 0
    var target: Double = 0
    var k: Double = 200
    var c: Double = 20

    mutating func cfg(_ response: Double, _ zeta: Double) {
        let w = 6.28318530718 / response
        k = w * w
        c = 2 * zeta * w
    }

    mutating func step(_ dt: Double) {
        var n = Int(ceil(dt / (1.0 / 240.0)))
        if n < 1 { n = 1 }
        if n > 64 { n = 64 }
        let h = dt / Double(n)
        for _ in 0..<n {
            let a = k * (target - x) - c * v
            v += a * h
            x += v * h
        }
    }

    mutating func snap(_ val: Double) {
        x = val
        target = val
        v = 0
    }

    var moving: Bool { abs(v) > 0.05 || abs(x - target) > 0.02 }
}
