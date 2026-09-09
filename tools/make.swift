import AppKit
import CoreGraphics

// Standalone generator for the profile banner: a space invader runs across and
// writes MANU in dashes behind it. Pure CoreGraphics, no dependencies.
//
// The sprite shape is taken from the GitHub avatar; the ink is purple.
//
//   swiftc -O make.swift -o make && ./make <output-dir>

// MARK: - Sprite

/// The classic crab invader, two frames, matching the avatar's shape.
let invaderFrames: [[String]] = [
    [
        "..#.....#..",
        "...#...#...",
        "..#######..",
        ".##.###.##.",
        "###########",
        "#.#######.#",
        "#.#.....#.#",
        "...##.##...",
    ],
    [
        "..#.....#..",
        "#..#...#..#",
        "#.#######.#",
        "###.###.###",
        "###########",
        ".#########.",
        "..#.....#..",
        ".#.......#.",
    ],
]

// MARK: - Type

let glyphs: [Character: [String]] = [
    "I": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "#####"],
    "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
    "N": ["#...#", "##..#", "#.#.#", "#.#.#", "#..##", "#...#", "#...#"],
    "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    ".": [".", ".", ".", ".", ".", ".", "#"],
]

let message = "M.A.N.U"
let glyphHeight = 7, letterGap = 2, tightGap = 1, spaceWidth = 3

/// Column offset of each character, and the total width in columns. Glyphs carry
/// their own width, so a dot takes two columns where a letter takes five.
func layout() -> (offsets: [(Character, Int)], columns: Int) {
    let characters = Array(message)
    var offsets: [(Character, Int)] = []
    var cursor = 0
    for (index, character) in characters.enumerated() {
        guard let glyph = glyphs[character], let row = glyph.first else {
            cursor += spaceWidth + letterGap
            continue
        }
        offsets.append((character, cursor))
        cursor += row.count
        guard index < characters.count - 1 else { continue }
        // Tighter either side of a dot, so M.A.N.U reads as one word.
        let next = characters[index + 1]
        cursor += (character == "." || next == ".") ? tightGap : letterGap
    }
    return (offsets, cursor)
}

// MARK: - Canvas

let ink = CGColor(red: 0xA8 / 255.0, green: 0x55 / 255.0, blue: 0xF7 / 255.0, alpha: 1)
let cell: CGFloat = 21          // text cell
let invaderCell: CGFloat = 16   // sprite cell
let size = CGSize(width: 900, height: 320)
let fps = 24.0
let loop = 2.6
let frameCount = Int(loop * fps)

let (offsets, totalColumns) = layout()
let textWidth = CGFloat(totalColumns) * cell
let textX = (size.width - textWidth) / 2
let textY: CGFloat = 155
let invaderW = CGFloat(11) * invaderCell
let invaderH = CGFloat(8) * invaderCell

func context() -> CGContext? {
    CGContext(
        data: nil, width: Int(size.width) * 2, height: Int(size.height) * 2,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
}

func render(frame index: Int) -> Data? {
    guard let ctx = context() else { return nil }
    ctx.scaleBy(x: 2, y: 2)
    // Flip to a top-left origin so the sprite grids read the way they are written.
    ctx.translateBy(x: 0, y: size.height)
    ctx.scaleBy(x: 1, y: -1)
    ctx.setFillColor(ink)

    let time = Double(index) / fps
    let progress = min(1, time / (loop * 0.80))
    let revealed = Double(totalColumns) * progress

    // The word, laid down column by column.
    for (character, column) in offsets {
        guard let glyph = glyphs[character] else { continue }
        for (row, line) in glyph.enumerated() {
            for (dx, mark) in line.enumerated() where mark == "#" {
                let absolute = column + dx
                guard Double(absolute) < revealed else { continue }
                // Each cell is a dash: wide, short, rounded.
                let rect = CGRect(
                    x: textX + CGFloat(absolute) * cell,
                    y: textY + CGFloat(row) * cell + cell * 0.24,
                    width: cell * 0.86, height: cell * 0.5
                )
                ctx.addPath(CGPath(roundedRect: rect, cornerWidth: cell * 0.22,
                                   cornerHeight: cell * 0.22, transform: nil))
                ctx.fillPath()
            }
        }
    }

    // The invader, leading the reveal, legs alternating.
    let sprite = invaderFrames[(index / 5) % invaderFrames.count]
    let originX = textX + textWidth * CGFloat(progress) - invaderW * 0.36
    let originY = textY - invaderH - 16
    // A gentle hover so it reads as moving rather than sliding.
    let hover = CGFloat(sin(time * 7.5)) * 3
    for (row, line) in sprite.enumerated() {
        for (column, mark) in line.enumerated() where mark == "#" {
            let rect = CGRect(
                x: originX + CGFloat(column) * invaderCell,
                y: originY + CGFloat(row) * invaderCell + hover,
                width: invaderCell - 1.4, height: invaderCell - 1.4
            )
            ctx.fill(rect)
        }
    }

    guard let image = ctx.makeImage() else { return nil }
    let rep = NSBitmapImageRep(cgImage: image)
    return rep.representation(using: .png, properties: [:])
}

let outputDirectory = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
try? FileManager.default.createDirectory(
    atPath: outputDirectory, withIntermediateDirectories: true
)
for index in 0..<frameCount {
    guard let data = render(frame: index) else { continue }
    let path = "\(outputDirectory)/\(String(format: "%03d", index)).png"
    try? data.write(to: URL(fileURLWithPath: path))
}
print("rendered \(frameCount) frames into \(outputDirectory)")
