import QtQuick

// Original wallpaper for scale and contrast. Every point is deterministic.
Canvas {
    id: sky
    onPaint: {
        const c = getContext("2d");
        c.reset();
        const w = width, h = height;
        c.scale(w / 1120, h / 630);
        const haze = c.createLinearGradient(0, 0, 0, 630);
        haze.addColorStop(0, "#17222e");
        haze.addColorStop(0.54, "#34424b");
        haze.addColorStop(1, "#69645e");
        c.fillStyle = haze;
        c.fillRect(0, 0, 1120, 630);
        for (let i = 1; i <= 95; ++i) {
            const x = (i * i * 113 + i * 57) % 1120;
            const y = (i * i * 13 + i * 99) % 575;
            c.fillStyle = Qt.rgba(.91,.89,.83, .19 + (i % 5) * .065);
            c.fillRect(x, y, i % 13 === 0 ? 2 : 1, i % 13 === 0 ? 2 : 1);
        }
        // Low planetary limb. Fine striations follow the curvature of the rock.
        c.save();
        c.beginPath();
        c.arc(745, 1140, 796, 0, 2 * Math.PI);
        c.clip();
        const rock = c.createLinearGradient(0, 344, 100, 630);
        rock.addColorStop(0, "#b4997e");
        rock.addColorStop(.08, "#807466");
        rock.addColorStop(.5, "#505356");
        rock.addColorStop(1, "#303a41");
        c.fillStyle = rock;
        c.fillRect(0, 340, 1120, 300);
        for (let i = 0; i < 100; ++i) {
            c.beginPath();
            for (let x = 0; x <= 1128; x += 8) {
                const y = 345 + i * 3.8 + (x - 745) ** 2 / 1500
                    + (5 + i * .06) * Math.sin(x / 63 + i / 11) + 3 * Math.sin(x / 22 - i / 6);
                if (x === 0) c.moveTo(x, y);
                else c.lineTo(x, y);
            }
            c.strokeStyle = i % 5 === 0 ? "#709c9685" : "#44262e38";
            c.lineWidth = i % 6 === 0 ? 1.7 : .65;
            c.stroke();
        }
        c.restore();
    }
}
