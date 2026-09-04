import QtQuick
import "../services"

// Base clicável com hover: o "button + :hover" do CSS. O conteúdo entra
// como filho (default property) e o fundo anima entre normal/hover/pressed.
Rectangle {
    id: root

    property color hoverColor: Theme.cardHover
    property color baseColor: "transparent"
    property color pressColor: hoverColor
    property bool disabled: false
    property alias hovered: mouse.containsMouse
    property alias cursorShape: mouse.cursorShape
    property string tooltip: ""

    signal clicked()
    signal rightClicked()

    color: disabled ? baseColor : mouse.pressed ? pressColor : (mouse.containsMouse ? hoverColor : baseColor)
    radius: 10

    implicitWidth: childrenRect.width
    implicitHeight: childrenRect.height

    Behavior on color {
        ColorAnimation {
            duration: 150
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        enabled: !root.disabled

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.rightClicked();
            else
                root.clicked();
        }
    }
}
