import org.kde.breeze.components

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

SessionManagementScreen {
    id: root
    property Item mainPasswordBox: passwordBox
    property bool showUsernamePrompt: !showUserList
    property int usernameFontSize
    property int fontSize: parseInt(config.fontSize)
    property string usernameFontColor
    property string lastUserName
    property bool loginScreenUiVisible: false
    property bool passwordFieldOutlined: config.PasswordFieldOutlined == "true"
    property bool hidePasswordRevealIcon: config.HidePasswordRevealIcon == "false"
    property int visibleBoundary: mapFromItem(loginButton, 0, 0).y
    onHeightChanged: visibleBoundary = mapFromItem(loginButton, 0, 0).y + loginButton.height + Kirigami.Units.smallSpacing

    signal loginRequest(string username, string password)

    onShowUsernamePromptChanged: {
        if (!showUsernamePrompt) {
            lastUserName = ""
        }
    }

    onUserSelected: {
        // Don't startLogin() here, because the signal is connected to the
        // Escape key as well, for which it wouldn't make sense to trigger
        // login.
        passwordBox.clear()
        focusFirstVisibleFormControl();
    }

    QQC2.StackView.onActivating: {
        // Controls are not visible yet.
        Qt.callLater(focusFirstVisibleFormControl);
    }

    function focusFirstVisibleFormControl() {
        const nextControl = (userNameInput.visible
            ? userNameInput
            : (passwordBox.visible
                ? passwordBox
                : loginButton));
        // Using TabFocusReason, so that the loginButton gets the visual highlight.
        nextControl.forceActiveFocus(Qt.TabFocusReason);
    }

    /*
    * Login has been requested with the following username and password
    * If username field is visible, it will be taken from that, otherwise from the "name" property of the currentIndex
    */
    function startLogin() {
        const username = showUsernamePrompt ? userNameInput.text : userList.selectedUser
        const password = passwordBox.text

        footer.enabled = false
        mainStack.enabled = false
        userListComponent.userList.opacity = 0.75

        // This is partly because it looks nicer, but more importantly it
        // works round a Qt bug that can trigger if the app is closed with a
        // TextField focused.
        //
        // See https://bugreports.qt.io/browse/QTBUG-55460
        loginButton.forceActiveFocus();
        loginRequest(username, password);
    }

    Input {
        id: userNameInput
        Layout.fillWidth: true
        Layout.preferredHeight: 30
        font.pointSize: fontSize + 1
        opacity: passwordFieldOutlined ? 1.0 : 0.75
        text: lastUserName
        visible: showUsernamePrompt
        focus: showUsernamePrompt && !lastUserName //if there's a username prompt it gets focus first, otherwise password does
        placeholderText: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "Username")
        placeholderTextColor: passwordFieldOutlined ? "white" : "white"
        color: "white"
        //horizontalAlignment: TextInput.AlignHCenter
        leftPadding: fontSize
        rightPadding: leftPadding
    }

    Input {
        id: passwordBox
        Layout.fillWidth: true
        font.pointSize: fontSize + 1
        Layout.preferredHeight: 30
        opacity: passwordFieldOutlined ? 1.0 : 0.75
        font.family: config.Font || "Noto Sans"
        placeholderText: config.PasswordFieldPlaceholderText || i18ndc("plasma-desktop-sddm-theme", "@info:placeholder in textfield", "Password")
        focus: !showUsernamePrompt || lastUserName
        echoMode: TextInput.Password
        onAccepted: startLogin()
        placeholderTextColor: passwordFieldOutlined ? "white" : "white"
        passwordCharacter: config.PasswordFieldCharacter || "●"
        color: "white"
        //horizontalAlignment: TextInput.AlignHCenter
        leftPadding: fontSize
        rightPadding: leftPadding

        Keys.onEscapePressed: {
            mainStack.currentItem.forceActiveFocus();
        }

        Keys.onPressed: event => {
            if (event.key == Qt.Key_Left && !text) {
                userList.decrementCurrentIndex();
                event.accepted = true
            }
            if (event.key == Qt.Key_Right && !text) {
                userList.incrementCurrentIndex();
                event.accepted = true
            }
        }

        Keys.onReleased: {
            if (loginButton.opacity == 0 && length > 0) {
                showLoginButton.start()
            }
            if (loginButton.opacity > 0 && length == 0) {
                hideLoginButton.start()
            }
        }

        Connections {
            target: sddm
            function onLoginFailed() {
                passwordBox.selectAll()
                passwordBox.forceActiveFocus()
            }
        }

        Image {
            id: loginButton
            source: "assets/login.svgz"
            smooth: true
            sourceSize: Qt.size(passwordBox.height, passwordBox.height)
            anchors {
                left: parent.right
                verticalCenter: parent.verticalCenter
            }
            anchors.leftMargin: 8
            visible: opacity > 0
            opacity: 0
            MouseArea {
                anchors.fill: parent
                onClicked: startLogin();
            }
            PropertyAnimation {
                id: showLoginButton
                target: loginButton
                properties: "opacity"
                to: 0.75
                duration: 100
            }
            PropertyAnimation {
                id: hideLoginButton
                target: loginButton
                properties: "opacity"
                to: 0
                duration: 80
            }
        }
    }
}
