/***************************************************************************
 *   Copyright (C) 2017 by Kai Uwe Broulik <kde@privat.broulik.de>         *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA .        *
 ***************************************************************************/

import QtQuick 2.2

import org.kde.plasma.private.volume 0.1

QtObject {
    id: pulseAudio

    signal streamsChanged

    // It's a JS object so we can do key lookup and don't need to take care of filtering duplicates.
    property var pidMatches: ({})

    // TODO Evict cache at some point, preferably if all instances of an application closed.
    function registerPidMatch(appName) {
        if (!hasPidMatch(appName)) {
            pidMatches[appName] = true;

            // In case this match is new, notify that streams might have changed.
            // This way we also catch the case when the non-playing instance
            // shows up first.
            // Only notify if we changed to avoid infinite recursion.
            streamsChanged();
        }
    }

    function hasPidMatch(appName) {
        return pidMatches[appName] === true;
    }

    function findStreams(key, value) {
        var streams = []
        for (var i = 0, length = instantiator.count; i < length; ++i) {
            var stream = instantiator.objectAt(i);
            if (stream[key] === value) {
                streams.push(stream);
            }
        }
        return streams
    }

    function streamsForAppName(appName) {
        return findStreams("appName", appName);
    }

    function streamsForPid(pid) {
        var streams = findStreams("pid", pid);

        if (streams.length === 0) {
            for (var i = 0, length = instantiator.count; i < length; ++i) {
                var stream = instantiator.objectAt(i);

                if (stream.parentPid === -1) {
                    stream.parentPid = backend.parentPid(stream.pid);
                }

                if (stream.parentPid === pid) {
                    streams.push(stream);
                }
            }
        }

        return streams;
    }

    // QtObject has no default property, hence adding the Instantiator to one explicitly.
    property var instantiator: Instantiator {
        model: PulseObjectFilterModel {
            filters: [ { role: "VirtualStream", value: false } ]
            sourceModel: SinkInputModel {}
        }

        delegate: QtObject {
            readonly property int pid: Client ? Client.properties["application.process.id"] : 0
            // Determined on demand.
            property int parentPid: -1
            readonly property string appName: Client ? Client.properties["application.name"] : ""
            readonly property bool muted: Muted
            // whether there is nothing actually going on on that stream
            readonly property bool corked: Corked

            function mute() {
                Muted = true
            }
            function unmute() {
                Muted = false
            }
        }

        onObjectAdded: pulseAudio.streamsChanged()
        onObjectRemoved: pulseAudio.streamsChanged()
    }
}
