#include "backend.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>

Backend::Backend(QObject *parent) : QObject(parent) {
    connect(&m_process, &QProcess::finished, this, [this](int exitCode, QProcess::ExitStatus status) {
        setBusy(false);
        if (exitCode != 0 || status != QProcess::NormalExit) {
            const QString err = QString::fromUtf8(m_process.readAllStandardError()).trimmed();
            setStatus(err.isEmpty() ? tr("hyprctl failed (exit %1)").arg(exitCode) : err);
        } else {
            setStatus(QString());
            const QByteArray out = m_process.readAllStandardOutput();
            // If the output looks like JSON (starts with '['), treat it as monitor list.
            if (out.trimmed().startsWith('['))
                parseMonitors(out);
        }
    });
    connect(&m_process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError err) {
        Q_UNUSED(err)
        setBusy(false);
        setStatus(tr("Failed to run hyprctl — check that Hyprland is running."));
    });

    refresh();
}

void Backend::refresh() {
    if (m_busy)
        return;
    // Clear status on explicit refresh.
    setStatus(QString());
    const QString hyprctl = QStandardPaths::findExecutable("hyprctl");
    if (hyprctl.isEmpty()) {
        setStatus(tr("hyprctl not found — is Hyprland running?"));
        return;
    }
    setBusy(true);
    m_process.start(hyprctl, {"monitors", "-j"});
}

void Backend::parseMonitors(const QByteArray &json) {
    const QJsonArray array = QJsonDocument::fromJson(json).array();
    QVariantList monitors;
    for (const QJsonValue &val : array) {
        const QJsonObject obj = val.toObject();
        QVariantMap mon;
        mon["name"]        = obj["name"].toString();
        mon["description"] = obj["description"].toString();
        mon["width"]       = obj["width"].toInt();
        mon["height"]      = obj["height"].toInt();
        mon["refreshRate"] = obj["refreshRate"].toDouble();
        mon["posX"]        = obj["x"].toInt();
        mon["posY"]        = obj["y"].toInt();
        mon["rotation"]    = transformToRotation(obj["transform"].toInt());
        mon["scale"]       = obj["scale"].toDouble();

        // Available modes are stored as an array of strings like "2560x1440@143.86Hz".
        QStringList modes;
        for (const QJsonValue &m : obj["availableModes"].toArray())
            modes.append(m.toString());
        mon["availableModes"] = modes;

        monitors.append(mon);
    }
    m_monitors = monitors;
    emit monitorsChanged();
}

void Backend::applyMonitor(const QString &name, const QString &resolution,
                           double refreshRate, int posX, int posY,
                           int rotation, double scale) {
    if (m_busy)
        return;

    // Find current monitor state to build the revert command.
    QString revertArgs;
    for (const QVariant &v : m_monitors) {
        const QVariantMap mon = v.toMap();
        if (mon["name"].toString() == name) {
            const int w = mon["width"].toInt(), h = mon["height"].toInt();
            const double hz = mon["refreshRate"].toDouble();
            const int px = mon["posX"].toInt(), py = mon["posY"].toInt();
            const int rot = mon["rotation"].toInt();
            const double sc = mon["scale"].toDouble();
            revertArgs = QString("monitor %1,%2x%3@%4,%5x%6,%7,transform,%8")
                .arg(name).arg(w).arg(h).arg(hz, 0, 'f', 2)
                .arg(px).arg(py).arg(sc, 0, 'f', 2).arg(rotationToTransform(rot));
            break;
        }
    }

    // Parse "WxH" out of the resolution string (resolution may be "2560x1440").
    // The @Hz part comes from refreshRate.
    const QString monitorArg = QString("monitor %1,%2@%3,%4x%5,%6,transform,%7")
        .arg(name)
        .arg(resolution)
        .arg(refreshRate, 0, 'f', 2)
        .arg(posX).arg(posY)
        .arg(scale, 0, 'f', 2)
        .arg(rotationToTransform(rotation));

    const QString hyprctl = QStandardPaths::findExecutable("hyprctl");
    if (hyprctl.isEmpty()) {
        setStatus(tr("hyprctl not found — is Hyprland running?"));
        return;
    }

    // Save current state before we overwrite it.
    if (!revertArgs.isEmpty())
        m_revertArgs = revertArgs;

    setBusy(true);
    m_process.start(hyprctl, {"keyword", monitorArg});
}

void Backend::resetLastChange() {
    if (m_busy || m_revertArgs.isEmpty())
        return;

    const QString hyprctl = QStandardPaths::findExecutable("hyprctl");
    if (hyprctl.isEmpty()) {
        setStatus(tr("hyprctl not found — is Hyprland running?"));
        return;
    }

    setBusy(true);
    // "keyword monitor <args>" — split on first space to get "keyword" then the rest.
    m_process.start(hyprctl, {"keyword", m_revertArgs});
    m_revertArgs.clear();
}

void Backend::setStatus(const QString &status) {
    if (m_status != status) {
        m_status = status;
        emit statusChanged();
    }
}

void Backend::setBusy(bool busy) {
    if (m_busy != busy) {
        m_busy = busy;
        emit busyChanged();
        // After a hyprctl keyword command finishes, re-read the monitor list.
        if (!busy && m_status.isEmpty())
            QMetaObject::invokeMethod(this, "refresh", Qt::QueuedConnection);
    }
}

int Backend::transformToRotation(int transform) {
    // Hyprland transform: 0=0°, 1=90°, 2=180°, 3=270°, 4–7 are flipped variants.
    switch (transform % 4) {
    case 1: return 90;
    case 2: return 180;
    case 3: return 270;
    default: return 0;
    }
}

int Backend::rotationToTransform(int rotation) {
    switch (rotation) {
    case 90:  return 1;
    case 180: return 2;
    case 270: return 3;
    default:  return 0;
    }
}
