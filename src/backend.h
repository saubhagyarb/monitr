#pragma once

#include <QObject>
#include <QProcess>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

// Backend handles all hyprctl calls; QML only manages layout.
class Backend : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList monitors READ monitors NOTIFY monitorsChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

public:
    explicit Backend(QObject *parent = nullptr);

    QVariantList monitors() const { return m_monitors; }
    QString status() const { return m_status; }
    bool busy() const { return m_busy; }

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void applyMonitor(const QString &name, const QString &resolution,
                                  double refreshRate, int posX, int posY,
                                  int rotation, double scale);
    Q_INVOKABLE void resetLastChange();

signals:
    void monitorsChanged();
    void statusChanged();
    void busyChanged();

private:
    void parseMonitors(const QByteArray &json);
    void runHyprctl(const QStringList &args, bool saveRevert = false,
                    const QString &revertArgs = {});
    void setStatus(const QString &status);
    void setBusy(bool busy);

    // Maps Hyprland transform int (0–7) to rotation degrees (0, 90, 180, 270).
    static int transformToRotation(int transform);
    // Maps rotation degrees to transform int.
    static int rotationToTransform(int rotation);

    QVariantList m_monitors;
    QString m_status;
    bool m_busy = false;

    // Arguments for the last applied command, used for undo (resetLastChange).
    QString m_revertArgs;

    QProcess m_process;
};
