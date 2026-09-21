import QtQuick
import QtQuick.Layouts
import "../services"

// Grade de calendário própria (a mesma do CenterPanel e do popup do relógio):
// semanas começando no domingo, hoje destacado com a cor primária.
ColumnLayout {
    id: root

    property int monthOffset: 0
    // recalculada a cada abertura pra não congelar na virada do dia
    property date today: new Date()

    // diâmetro da bolinha do dia. O popup do relógio tem largura de sobra e
    // fica no padrão; o dashboard passa um valor menor.
    property int cellSize: 28
    property int dayFontSize: 12

    readonly property var grid: {
        const base = new Date(today.getFullYear(), today.getMonth() + monthOffset, 1);
        const year = base.getFullYear();
        const month = base.getMonth();
        const lead = base.getDay(); // 0 = domingo
        const days = new Date(year, month + 1, 0).getDate();

        const cells = [];
        for (let i = 0; i < lead; i++)
            cells.push(0);
        for (let d = 1; d <= days; d++)
            cells.push(d);
        while (cells.length % 7 !== 0)
            cells.push(0);

        return {
            cells: cells,
            title: `${Fmt.months[month]} ${year}`,
            isCurrentMonth: year === today.getFullYear() && month === today.getMonth(),
            todayDay: today.getDate(),
        };
    }

    readonly property string title: grid.title

    spacing: 4

    RowLayout {
        Layout.fillWidth: true

        Repeater {
            model: ["D", "S", "T", "Q", "Q", "S", "S"]

            delegate: UiText {
                required property string modelData
                Layout.fillWidth: true
                text: modelData
                font.pixelSize: 10
                font.bold: true
                color: Theme.fgFaint
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    GridLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        columns: 7
        rowSpacing: 2
        columnSpacing: 2

        Repeater {
            model: root.grid.cells

            delegate: Item {
                id: cell

                required property int modelData

                readonly property bool isToday: root.grid.isCurrentMonth
                    && modelData === root.grid.todayDay

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: root.cellSize

                Rectangle {
                    anchors.centerIn: parent
                    width: root.cellSize
                    height: root.cellSize
                    radius: width / 2
                    color: cell.isToday ? Theme.primary : "transparent"
                    visible: cell.modelData > 0

                    UiText {
                        anchors.centerIn: parent
                        text: cell.modelData > 0 ? String(cell.modelData) : ""
                        font.pixelSize: root.dayFontSize
                        color: cell.isToday ? "#ffffff" : Theme.fgMid
                    }
                }
            }
        }
    }
}
