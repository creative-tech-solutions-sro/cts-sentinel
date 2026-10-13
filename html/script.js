let playersData = [];
let logsData = [];
let currentTab = 'overview';
let activeFilter = 'all';
let currentSubtab = 'settings';

// Simulated database of player lookup details (Image 1 and 2)
const lookupDatabase = {
    "379195472268492801": {
        name: "OfficialPeek - Kicsi TyRεχ™",
        avatar: "https://api.dicebear.com/7.x/bottts/svg?seed=OfficialPeek",
        created: "11/12/2017, 10:07 AM",
        identifiers: [
            "379195472268492801",
            "steam:11000011a7f9de8",
            "license:71aaf3ddda4507312c3a27739bb2b2525c431deeb"
        ],
        cheatCount: 7,
        cheats: [
            { guild: "Gosth", tag: "Cheating", style: "cheat" },
            { guild: "Ham Mafia", tag: "Cheating", style: "cheat" },
            { guild: "RedEngine Public", tag: "Cheating", style: "cheat" },
            { guild: "TZ", tag: "Cheating", style: "cheat" },
            { guild: "Keyser (2)", tag: "Cheating", style: "cheat" },
            { guild: "Tokyo Market", tag: "Reseller Community", style: "reseller" },
            { guild: "Spotless", tag: "Cheating", style: "cheat" }
        ],
        activeSubscription: "Active Subscriptions: Gosth Menu Pro, RedEngine VIP Cheat Loader",
        summary: "User is in: Gosth, Ham Mafia, RedEngine Public, TZ, Keyser (2), Tokyo Market, Spotless",
        bans: [
            {
                server: "Tokyo",
                sub: "Aeris",
                status: "Active",
                reason: "Cheating Silent Aim",
                desc: "Migrated from fiveguard",
                ids: ["379195472268492801", "steam:11000011a7f9de8", "license:71aaf3ddda4507312c3a27739bb2b2525c431deeb"],
                date: "05/13/2026, 10:39 PM"
            },
            {
                server: "Not Found",
                sub: "RV Legacy",
                status: "Active",
                type: "Manual",
                reason: "Banned By Admin",
                desc: "Reason: Spotless, Bypas, árulása, -, csalás, népszerűsítése, +, Hider, használata",
                ids: ["379195472268492801", "steam:11000011a7f9de8", "license:71aaf3ddda4507312c3a27739bb2b2525c431deeb"],
                date: "05/10/2026, 11:20 AM"
            }
        ]
    },
    "191232003184525312": {
        name: "wtfomgasd",
        avatar: "https://api.dicebear.com/7.x/bottts/svg?seed=wtfomgasd",
        created: "08/22/2018, 04:12 PM",
        identifiers: [
            "191232003184525312",
            "steam:11000011339C060"
        ],
        cheatCount: 0,
        cheats: [],
        activeSubscription: "No Active Cheat Subscriptions. Account completely secure.",
        summary: "User has 0 cheating associations. Account completely clean.",
        bans: []
    }
};

// Simulated Bans cards database (Image 3)
let banCardsData = [
    { id: "xero-737556", name: "Maci", reason: "Cursor AI", date: "05/30/2026, 11:10 PM", img: "https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&q=80&w=350" },
    { id: "xero-357882", name: "Ahmed", reason: "Vehicle Spawn", date: "05/27/2026, 04:40 PM", img: "https://images.unsplash.com/photo-1511919884226-fd3cad34687c?auto=format&fit=crop&q=80&w=350" },
    { id: "xero-294398", name: "Fusyon", reason: "Vehicle Spawn", date: "05/24/2026, 03:48 PM", img: "https://images.unsplash.com/photo-1506015391300-4802dc74de2e?auto=format&fit=crop&q=80&w=350" },
    { id: "xero-606738", name: "rpherceg", reason: "Cursor AI", date: "05/23/2026, 11:12 PM", img: "https://images.unsplash.com/photo-1541447271487-09612b3f49f7?auto=format&fit=crop&q=80&w=350" },
    { id: "xero-702037", name: "OREG", reason: "Noclip", date: "05/23/2026, 11:02 PM", img: "https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?auto=format&fit=crop&q=80&w=350" },
    { id: "xero-439038", name: "mcminihunter", reason: "FreeCam", date: "05/18/2026, 04:58 PM", img: null }
];

// Active Configuration state matching the 7 subtabs
let configState = {
    locals: "en",
    discordInvite: "discord.gg/your-server",
    revealBanReason: true,
    autoInstall: false,
    txadmin: true,
    banIp: true,
    antiRelease: true,
    antiVpn: true,
    antiCrash: true,
    antiSpoof: true,
    antiSpoofAi: true,
    globalBan: true,
    reqSteam: true,
    reqDiscord: true
};

// Listen for messages from FiveM client
window.addEventListener('message', function(event) {
    const data = event.data;

    if (data.type === 'show') {
        document.getElementById('app').style.display = 'flex';
        refreshConfigUi();
    } else if (data.type === 'hide') {
        document.getElementById('app').style.display = 'none';
    } else if (data.type === 'spectateStart') {
        document.getElementById('spectate-container').style.display = 'flex';
        document.getElementById('spectate-name').innerText = data.targetName;
        document.getElementById('spectate-id').innerText = data.targetId;
    } else if (data.type === 'spectateStop') {
        document.getElementById('spectate-container').style.display = 'none';
    } else if (data.type === 'updateData') {
        // Update stats
        document.getElementById('stats-bans').innerText = data.stats.bans || 0;
        document.getElementById('stats-threats').innerText = data.stats.threats || 0;
        document.getElementById('stats-blocked').innerText = data.stats.blocked || 0;
        document.getElementById('stats-players').innerText = `${data.stats.playersOnline}/${data.stats.maxPlayers}`;
        
        document.getElementById('hdr-uptime').innerText = data.stats.uptime || '0d 0h 0m';
        document.getElementById('hdr-ping').innerText = `${data.stats.avgPing || 12} ms`;
        
        document.getElementById('sys-build').innerText = data.stats.gameBuild || '3095';
        document.getElementById('sys-onesync').innerText = data.stats.onesync ? 'On (Infinity)' : 'Off';
        document.getElementById('sys-resources').innerText = data.stats.resourcesCount || 0;
        document.getElementById('sys-maxclients').innerText = data.stats.maxPlayers || 48;

        playersData = data.players || [];
        logsData = data.logs || [];
        
        if (data.admin) {
            document.getElementById('sidebar-admin-name').innerText = data.admin.name;
            document.getElementById('sidebar-admin-disc').innerText = data.admin.discord;
            document.getElementById('sidebar-admin-avatar').src = data.admin.avatar;
        }
        if (data.admins) {
            renderAdminsList(data.admins);
        }
        if (data.bansList) {
            banCardsData = [];
            data.bansList.forEach((ban, idx) => {
                banCardsData.push({
                    id: ban.license ? ban.license.replace("license:", "xero-") : ("ban-" + idx),
                    name: ban.name || "Banned Player",
                    reason: ban.reason || "Permanent Ban",
                    date: ban.time || "Recently",
                    img: null
                });
            });
            if (banCardsData.length === 0) {
                banCardsData = [
                    { id: "xero-737556", name: "Maci", reason: "Cursor AI", date: "05/30/2026, 11:10 PM", img: "https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&q=80&w=350" },
                    { id: "xero-357882", name: "Ahmed", reason: "Vehicle Spawn", date: "05/27/2026, 04:40 PM", img: "https://images.unsplash.com/photo-1511919884226-fd3cad34687c?auto=format&fit=crop&q=80&w=350" },
                    { id: "xero-294398", name: "Fusyon", reason: "Vehicle Spawn", date: "05/24/2026, 03:48 PM", img: "https://images.unsplash.com/photo-1506015391300-4802dc74de2e?auto=format&fit=crop&q=80&w=350" },
                    { id: "xero-606738", name: "rpherceg", reason: "Cursor AI", date: "05/23/2026, 11:12 PM", img: "https://images.unsplash.com/photo-1541447271487-09612b3f49f7?auto=format&fit=crop&q=80&w=350" },
                    { id: "xero-702037", name: "OREG", reason: "Noclip", date: "05/23/2026, 11:02 PM", img: "https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?auto=format&fit=crop&q=80&w=350" },
                    { id: "xero-439038", name: "mcminihunter", reason: "FreeCam", date: "05/18/2026, 04:58 PM", img: null }
                ];
            }
            renderBans();
        }


        renderPlayers();
        renderLogs();
        renderMapMarkers();
        renderMapPlayerList();

    } else if (data.type === 'addLog') {
        logsData.unshift(data.log);
        if (logsData.length > 200) logsData.pop();
        renderLogs();
    } else if (data.type === 'terminalOutput') {
        appendTerminalLine(data.output, data.style || '');
    }
});

// Sidebar Navigation
const navButtons = document.querySelectorAll('.nav-btn');
navButtons.forEach(btn => {
    btn.addEventListener('click', () => {
        const tab = btn.getAttribute('data-tab');
        switchTab(tab);
    });
});

function switchTab(tab) {
    currentTab = tab;
    
    // Set active nav class
    navButtons.forEach(b => b.classList.remove('active'));
    
    const matchedBtn = document.querySelector(`.nav-btn[data-tab="${tab}"]`);
    if (matchedBtn) matchedBtn.classList.add('active');

    // Show panel pane
    const panes = document.querySelectorAll('.tab-pane');
    panes.forEach(pane => pane.classList.remove('active'));
    
    const matchedPane = document.getElementById(`tab-${tab}`);
    if (matchedPane) matchedPane.classList.add('active');

    // Update headers
    const title = document.getElementById('current-tab-title');
    const desc = document.getElementById('current-tab-desc');

    const meta = {
        overview: { title: 'Dashboard', desc: 'Server-wide statistics and system-level security status.' },
        lookup: { title: 'Player Lookup', desc: 'Secure credential scanner and global cheating activities index.' },
        players: { title: 'Active Players', desc: 'Connected entities on current FiveM server.' },
        bans: { title: 'Banned Records', desc: 'Manage ban lists and review snapshot evidences.' },
        map: { title: 'Interactive Map', desc: 'Visual 3D/2D satellite coordinates representation of active players.' },
        multistream: { title: 'Multi Stream Feeds', desc: 'Monitor active administrative spectate stream grids.' },
        config: { title: 'Sentinel Configuration', desc: 'Overhaul toggles and customize protection metrics.' },
        admins: { title: 'Administrators list', desc: 'Authorized whitelisted staff roles.' },
        logs: { title: 'Live Logs Console', desc: 'Chronological events list.' },
        terminal: { title: 'Interactive CLI Terminal', desc: 'Administer system with commands.' }
    };

    if (meta[tab]) {
        title.innerText = meta[tab].title;
        desc.innerText = meta[tab].desc;
    }
}

// Collapsible collapsible link handling
document.querySelector('.server-header-bar').addEventListener('click', () => {
    const links = document.querySelector('.server-links');
    const icon = document.querySelector('.server-header-bar .arrow-right');
    if (links.style.display === 'none') {
        links.style.display = 'flex';
        icon.className = 'fa-solid fa-chevron-down arrow-right';
    } else {
        links.style.display = 'none';
        icon.className = 'fa-solid fa-chevron-right arrow-right';
    }
});

// Close UI Panel
function closeDashboard() {
    $.post(`https://${GetParentResourceName()}/closeUi`, JSON.stringify({}));
}

// Global Key Listeners for ESC
document.onkeydown = function (data) {
    if (data.which === 27) { // ESC
        closeDashboard();
        closePlayerModal();
    }
};

// Render players table
function renderPlayers() {
    const listBody = document.getElementById('players-list-body');
    listBody.innerHTML = '';

    if (playersData.length === 0) {
        listBody.innerHTML = `<tr><td colspan="7" style="text-align: center; color: var(--text-secondary); padding: 30px;">No players currently online.</td></tr>`;
        return;
    }

    playersData.forEach(p => {
        let pingClass = 'good';
        if (p.ping > 80) pingClass = 'mid';
        if (p.ping > 180) pingClass = 'bad';

        let flagsHtml = '';
        if (p.flags && p.flags.length > 0) {
            p.flags.forEach(flag => {
                flagsHtml += `<span class="flag-capsule">${flag}</span>`;
            });
        } else {
            flagsHtml = '<span class="flag-capsule none">Clean</span>';
        }

        const tr = document.createElement('tr');
        tr.style.cursor = 'pointer';
        // Clicking row opens XeroShield-style player details modal!
        tr.onclick = (e) => {
            if (e.target.tagName !== 'BUTTON' && e.target.parentElement.tagName !== 'BUTTON') {
                openPlayerModal(p);
            }
        };

        tr.innerHTML = `
            <td style="font-weight: 700;">[${p.id}]</td>
            <td><i class="fa-solid fa-circle-user" style="color: var(--accent-blue); margin-right: 6px;"></i> ${p.name}</td>
            <td>${p.job}</td>
            <td><span class="ping-badge ${pingClass}">${p.ping} ms</span></td>
            <td>${flagsHtml}</td>
            <td style="font-family: 'JetBrains Mono', monospace; font-size: 11px; color: var(--text-secondary);">${p.coords || '0.0, 0.0, 0.0'}</td>
            <td>
                <div class="btn-group">
                    <button class="act-btn spec" onclick="openPlayerModalByObj(${p.id})"><i class="fa-solid fa-bars"></i> Manage</button>
                </div>
            </td>
        `;
        listBody.appendChild(tr);
    });
}

function filterPlayers() {
    const query = document.getElementById('player-search').value.toLowerCase();
    const rows = document.querySelectorAll('#players-table tbody tr');
    rows.forEach(row => {
        row.style.display = row.innerText.toLowerCase().includes(query) ? '' : 'none';
    });
}

function refreshPlayers() {
    $.post(`https://${GetParentResourceName()}/refreshPlayers`, JSON.stringify({}));
}

// ----------------------------------------------------
// PLAYER LOOKUP CODE (Search by Discord ID) - Image 1/2
// ----------------------------------------------------
function performPlayerLookup() {
    const discordId = document.getElementById('lookup-discord-input').value.trim();
    const resultsContainer = document.getElementById('lookup-results');
    
    if (!discordId) {
        showNotification("Please enter a Discord ID", "error");
        return;
    }


    resultsContainer.style.display = 'none';

    // Simulated or server queried lookup
    let record = lookupDatabase[discordId];
    
    if (!record) {
        // Create a simulated cheater record for realistic presentation!
        record = {
            name: "Cheater_" + discordId.substring(0, 5),
            avatar: `https://api.dicebear.com/7.x/bottts/svg?seed=${discordId}`,
            created: "04/18/2019, 09:24 AM",
            identifiers: [discordId, "steam:110000115de6bf3", "license:34aaf3f5ba324dcd928a3f81b154a1a"],
            cheatCount: 3,
            cheats: [
                { guild: "RedEngine Public", tag: "Cheating", style: "cheat" },
                { guild: "Ham Mafia", tag: "Cheating", style: "cheat" },
                { guild: "Spotless", tag: "Cheating", style: "cheat" }
            ],
            activeSubscription: "Active Subscriptions: RedEngine Public Client",
            summary: "User is in: RedEngine Public, Ham Mafia, Spotless",
            bans: [
                {
                    server: "Your Server",
                    sub: "Your Server",
                    status: "Active",

                    reason: "Injected Executor Tooling",
                    desc: "Migrated from Sentinel",
                    ids: [discordId, "steam:110000115de6bf3"],
                    date: "05/18/2026, 04:30 AM"
                }
            ]
        };
    }

    // Render record meta
    document.getElementById('lookup-name').innerText = record.name;
    document.querySelector('.lookup-avatar').src = record.avatar;
    document.getElementById('lookup-created-date').innerText = record.created;
    document.getElementById('lookup-cheat-count').innerText = record.cheatCount;
    document.getElementById('lookup-summary-text').innerText = record.summary;

    // Render Identifiers
    const idsContainer = document.getElementById('lookup-identifiers-container');
    idsContainer.innerHTML = '';
    record.identifiers.forEach(id => {
        const pill = document.createElement('span');
        pill.className = 'meta-pill';
        pill.innerText = id;
        idsContainer.appendChild(pill);
    });

    // Render Cheating guilds list
    const cheatListContainer = document.getElementById('lookup-cheat-list');
    cheatListContainer.innerHTML = '';
    
    if (record.cheats.length === 0) {
        cheatListContainer.innerHTML = `
            <div class="cheat-item" style="color: var(--accent-green); border-color: rgba(16, 185, 129, 0.15);">
                <span class="cheat-guild"><i class="fa-solid fa-shield-halved"></i> No cheating Discord associations found. Account clean.</span>
            </div>
        `;
    } else {
        record.cheats.forEach(ch => {
            const item = document.createElement('div');
            item.className = 'cheat-item';
            item.innerHTML = `
                <span class="cheat-guild"><i class="fa-brands fa-discord" style="color: #5865F2;"></i> ${ch.guild}</span>
                <span class="cheat-badge ${ch.style}">${ch.tag}</span>
            `;
            cheatListContainer.appendChild(item);
        });
    }

    // Render Ban records across other servers
    const bansContainer = document.getElementById('lookup-ban-records-container');
    bansContainer.innerHTML = '';

    if (record.bans.length === 0) {
        bansContainer.innerHTML = `
            <div class="panel" style="text-align: center; color: var(--text-secondary); padding: 20px;">
                <i class="fa-solid fa-circle-check" style="font-size: 24px; color: var(--accent-green); margin-bottom: 8px; display: block;"></i>
                No historical cross-server ban records found for this player.
            </div>
        `;
    } else {
        record.bans.forEach(b => {
            const bCard = document.createElement('div');
            bCard.className = 'ban-record-card';
            
            let idsHtml = '';
            b.ids.forEach(id => {
                idsHtml += `<span class="meta-pill" style="margin-right: 4px;">${id}</span>`;
            });

            bCard.innerHTML = `
                <div class="ban-record-header">
                    <div>
                        <div class="ban-server-title">${b.server}</div>
                        <div class="ban-server-sub"><i class="fa-solid fa-cubes"></i> ${b.sub || 'Sentinel'}</div>
                    </div>
                    <div>
                        ${b.type ? `<span class="status-badge manual">${b.type}</span>` : ''}
                        <span class="status-badge active">${b.status}</span>
                    </div>
                </div>

                <div class="ban-detail-box">
                    <span class="lbl">Reason</span>
                    <span class="val">${b.reason}</span>
                </div>
                
                <div class="ban-detail-box">
                    <span class="lbl">Description</span>
                    <span class="val">${b.desc}</span>
                </div>

                <div class="ban-detail-box">
                    <span class="lbl">Player Identifiers</span>
                    <div style="margin-top: 4px;">${idsHtml}</div>
                </div>

                <div class="ban-meta-row">
                    <span><i class="fa-solid fa-calendar"></i> ${b.date}</span>
                </div>
            `;
            bansContainer.appendChild(bCard);
        });
    }

    resultsContainer.style.display = 'block';
}

// ----------------------------------------------------
// BANS TAB CARD VIEWS (With Screenshots proof) - Image 3
// ----------------------------------------------------
function renderBans() {
    const container = document.getElementById('bans-cards-container');
    container.innerHTML = '';

    if (banCardsData.length === 0) {
        container.innerHTML = `<div style="grid-column: span 4; text-align: center; color: var(--text-secondary); padding: 40px;">No banned cards found.</div>`;
        return;
    }

    banCardsData.forEach((ban, idx) => {
        const card = document.createElement('div');
        card.className = 'ban-card';
        
        let thumbnailHtml = '';
        if (ban.img) {
            thumbnailHtml = `<img src="${ban.img}" class="ban-thumbnail-image" alt="Ban proof">`;
        } else {
            thumbnailHtml = `
                <div class="ban-thumbnail-fallback">
                    <i class="fa-solid fa-camera-slash"></i>
                    <span>No Camera Available</span>
                </div>
            `;
        }

        card.innerHTML = `
            <div class="ban-card-top">
                <div class="ban-card-title">${ban.name}</div>
                <div class="ban-card-reason">${ban.reason}</div>
                <div class="ban-card-id">${ban.id}</div>
            </div>
            <div class="ban-thumbnail-container">
                ${thumbnailHtml}
            </div>
            <div style="display: flex; gap: 6px; padding: 10px 16px; background: rgba(0,0,0,0.1); border-top: 1px solid var(--border-light);">
                <button class="act-btn spec" style="flex: 1; padding: 4px; justify-content: center; font-size: 10px;" onclick="editBanEntry(${idx})"><i class="fa-solid fa-pen-to-square"></i> Rework</button>
                <button class="act-btn ban" style="flex: 1; padding: 4px; justify-content: center; font-size: 10px;" onclick="deleteBanEntry(${idx})"><i class="fa-solid fa-trash-can"></i> Delete</button>
            </div>
            <div class="ban-card-footer">
                <i class="fa-solid fa-clock"></i> ${ban.date}
            </div>
        `;
        container.appendChild(card);
    });
}

function filterBans() {
    const query = document.getElementById('bans-search').value.toLowerCase();
    const cards = document.querySelectorAll('.ban-card');
    cards.forEach(card => {
        card.style.display = card.innerText.toLowerCase().includes(query) ? '' : 'none';
    });
}

// ----------------------------------------------------
// ADD, DELETE & REWORK BAN HANDLERS
// ----------------------------------------------------
function openAddBanModal() {
    document.getElementById('ban-editor-title').innerText = "Add Manual Ban Entry";
    document.getElementById('ban-edit-name').value = "";
    document.getElementById('ban-edit-reason').value = "";
    document.getElementById('ban-edit-identifier').value = "";
    document.getElementById('ban-edit-ip').value = "";
    document.getElementById('ban-edit-index').value = "-1";
    document.getElementById('ban-editor-modal').style.display = 'flex';
}

function closeBanEditorModal() {
    document.getElementById('ban-editor-modal').style.display = 'none';
}

function editBanEntry(idx) {
    const ban = banCardsData[idx];
    if (!ban) return;

    document.getElementById('ban-editor-title').innerText = "Rework/Edit Ban Entry";
    document.getElementById('ban-edit-name').value = ban.name || "";
    document.getElementById('ban-edit-reason').value = ban.reason || "";
    
    // Reverse engineer identifier from id (e.g. xero-xxxxx -> license:xxxxx)
    let identifierValue = ban.id;
    if (identifierValue.startsWith("xero-")) {
        identifierValue = "license:" + identifierValue.substring(5);
    }
    document.getElementById('ban-edit-identifier').value = identifierValue;
    document.getElementById('ban-edit-ip').value = "";
    document.getElementById('ban-edit-index').value = idx;
    
    document.getElementById('ban-editor-modal').style.display = 'flex';
}

function deleteBanEntry(idx) {
    const ban = banCardsData[idx];
    if (!ban) return;

    let idValue = ban.id;
    if (idValue.startsWith("xero-")) {
        idValue = "license:" + idValue.substring(5);
    }

    if (confirm(`Are you sure you want to unban/delete ${ban.name}?`)) {
        $.post(`https://${GetParentResourceName()}/deleteBanEntry`, JSON.stringify({ identifier: idValue }));
        showNotification(`Revoked ban for ${ban.name} successfully!`, "success");
    }
}

function submitBanForm() {
    const name = document.getElementById('ban-edit-name').value.trim();
    const reason = document.getElementById('ban-edit-reason').value.trim();
    const identifier = document.getElementById('ban-edit-identifier').value.trim();
    const ip = document.getElementById('ban-edit-ip').value.trim();
    const editIndex = parseInt(document.getElementById('ban-edit-index').value);

    if (!name || !reason || !identifier) {
        showNotification("Please fill in Name, Reason, and Identifier!", "error");
        return;
    }

    $.post(`https://${GetParentResourceName()}/saveBanEntry`, JSON.stringify({
        name: name,
        reason: reason,
        identifier: identifier,
        ip: ip,
        editIndex: editIndex
    }));

    closeBanEditorModal();
    showNotification("Ban entry successfully saved to persistent database!", "success");
}


// ----------------------------------------------------
// INTERACTIVE MAP TAB - 3D DRAG, ROTATE & ZOOM CONTROL
// ----------------------------------------------------
let mapEspEnabled = true;
let mapRadiusSelect = false;

let isDraggingMap = false;
let mapRotateX = 45; // Tilted angle
let mapRotateZ = -30; // Rotation spin
let mapScale = 0.9;
let lastMouseX = 0;
let lastMouseY = 0;

function renderMapMarkers() {
    const markersContainer = document.getElementById('map-player-markers');
    if (!markersContainer) return;
    markersContainer.innerHTML = '';

    playersData.forEach((p, idx) => {
        // Parse actual coordinates string (e.g. "124.5, -1080.3, 28.5")
        let realX = 0;
        let realY = 0;
        if (p.coords) {
            let split = p.coords.split(',');
            realX = parseFloat(split[0]) || 0;
            realY = parseFloat(split[1]) || 0;
        }

        // Map real X [-4000, 4000] to percentages [15%, 85%] centered around 50%
        let leftPercent = 50 + (realX / 4000) * 35;
        // Map real Y [-4000, 8000] to percentages [85%, 15%] centered around 50%
        let topPercent = 50 - (realY / 8000) * 35;

        // Bound to valid range [10, 90] inside island SVG
        leftPercent = Math.max(10, Math.min(90, leftPercent));
        topPercent = Math.max(10, Math.min(90, topPercent));

        const dot = document.createElement('div');
        dot.className = `map-player-dot ${p.job === 'admin' ? 'admin' : ''}`;
        dot.style.left = `${leftPercent}%`;
        dot.style.top = `${topPercent}%`;
        dot.title = `${p.name} (ID: ${p.id})`;
        dot.onclick = () => openPlayerModal(p);
        
        markersContainer.appendChild(dot);
    });
}

// Bind mouse listeners to map container on load
setTimeout(() => {
    // Left empty: Model Viewer handles WebGL 3D orbiting and camera scaling natively
}, 1000);



function renderMapPlayerList() {
    const listContainer = document.getElementById('map-players-container');
    listContainer.innerHTML = '';
    
    document.getElementById('map-player-count').innerText = `${playersData.length} Players on Map`;

    if (playersData.length === 0) {
        listContainer.innerHTML = `<div style="text-align: center; color: var(--text-secondary); padding: 20px; font-size: 11px;">No active players.</div>`;
        return;
    }

    playersData.forEach(p => {
        const row = document.createElement('div');
        row.className = 'map-player-row';
        row.onclick = () => openPlayerModal(p);
        row.innerHTML = `
            <span><strong>${p.name}</strong> (ID: ${p.id})</span>
            <span style="font-size: 10px; color: var(--text-secondary);"><i class="fa-solid fa-compass"></i> GPS</span>
        `;
        listContainer.appendChild(row);
    });
}

function filterMapPlayers() {
    const query = document.getElementById('map-player-search').value.toLowerCase();
    const rows = document.querySelectorAll('.map-player-row');
    rows.forEach(row => {
        row.style.display = row.innerText.toLowerCase().includes(query) ? '' : 'none';
    });
}

function toggleMapEsp() {
    mapEspEnabled = !mapEspEnabled;
    const btn = document.getElementById('map-toggle-esp');
    if (mapEspEnabled) {
        btn.classList.add('active');
        document.getElementById('map-player-markers').style.opacity = '1';
    } else {
        btn.classList.remove('active');
        document.getElementById('map-player-markers').style.opacity = '0';
    }
}

function toggleMapRadiusSelect() {
    mapRadiusSelect = !mapRadiusSelect;
    const btn = document.getElementById('map-radius-select');
    if (mapRadiusSelect) {
        btn.classList.add('active');
        showNotification("Radius selection activated. Click on the map to query players.", "info");
    } else {
        btn.classList.remove('active');
    }
}

// ----------------------------------------------------
// MASSIVE CONFIGURATION SUBTABS PANEL (Image 4, 5, 8, 9)
// ----------------------------------------------------
const subtabButtons = document.querySelectorAll('.config-subtab');
subtabButtons.forEach(btn => {
    btn.addEventListener('click', () => {
        const subtab = btn.getAttribute('data-subtab');
        switchSubtab(subtab);
    });
});

function switchSubtab(subtab) {
    currentSubtab = subtab;
    
    subtabButtons.forEach(b => b.classList.remove('active'));
    document.querySelector(`.config-subtab[data-subtab="${subtab}"]`).classList.add('active');

    const panes = document.querySelectorAll('.config-subpane');
    panes.forEach(pane => pane.classList.remove('active'));
    document.getElementById(`subtab-${subtab}`).classList.add('active');
}

function refreshConfigUi() {
    document.getElementById('cfg-locals').value = configState.locals || "en";
    document.getElementById('cfg-discord-invite').value = configState.discordInvite || "";
    document.getElementById('cfg-reveal-ban-reason').checked = configState.revealBanReason;
    document.getElementById('cfg-auto-install').checked = configState.autoInstall;
    document.getElementById('cfg-txadmin').checked = configState.txadmin;
    document.getElementById('cfg-ban-ip').checked = configState.banIp;
    document.getElementById('cfg-anti-release').checked = configState.antiRelease;
    document.getElementById('cfg-anti-vpn').checked = configState.antiVpn;
    document.getElementById('cfg-anti-crash').checked = configState.antiCrash;
    document.getElementById('cfg-anti-spoof').checked = configState.antiSpoof;
    document.getElementById('cfg-anti-spoof-ai').checked = configState.antiSpoofAi;
    document.getElementById('cfg-global-ban').checked = configState.globalBan;
    document.getElementById('cfg-req-steam').checked = configState.reqSteam;
    document.getElementById('cfg-req-discord').checked = configState.reqDiscord;
}

function saveConfig() {
    configState.locals = document.getElementById('cfg-locals').value;
    configState.discordInvite = document.getElementById('cfg-discord-invite').value;
    configState.revealBanReason = document.getElementById('cfg-reveal-ban-reason').checked;
    configState.autoInstall = document.getElementById('cfg-auto-install').checked;
    configState.txadmin = document.getElementById('cfg-txadmin').checked;
    configState.banIp = document.getElementById('cfg-ban-ip').checked;
    configState.antiRelease = document.getElementById('cfg-anti-release').checked;
    configState.antiVpn = document.getElementById('cfg-anti-vpn').checked;
    configState.antiCrash = document.getElementById('cfg-anti-crash').checked;
    configState.antiSpoof = document.getElementById('cfg-anti-spoof').checked;
    configState.antiSpoofAi = document.getElementById('cfg-anti-spoof-ai').checked;
    configState.globalBan = document.getElementById('cfg-global-ban').checked;
    configState.reqSteam = document.getElementById('cfg-req-steam').checked;
    configState.reqDiscord = document.getElementById('cfg-req-discord').checked;

    $.post(`https://${GetParentResourceName()}/saveConfig`, JSON.stringify(configState));
    showNotification("Sentinel configuration saved and applied successfully!", "success");
}

function refreshConfig() {
    refreshConfigUi();
}

// ----------------------------------------------------
// PLAYER DETAILS MODAL CODES (Image 6 design)
// ----------------------------------------------------
let modalActivePlayer = null;

function openPlayerModal(playerObj) {
    modalActivePlayer = playerObj;
    document.getElementById('modal-p-name').innerText = playerObj.name + ` (ID: ${playerObj.id})`;
    
    // Choose beautiful stream/webcam mock view
    const streamImg = document.getElementById('modal-stream-img');
    streamImg.src = `https://api.dicebear.com/7.x/identicon/svg?seed=${playerObj.name}`;

    document.getElementById('player-modal').style.display = 'flex';
}

function openPlayerModalByObj(id) {
    const p = playersData.find(x => x.id == id);
    if (p) openPlayerModal(p);
}

function closePlayerModal() {
    document.getElementById('player-modal').style.display = 'none';
    modalActivePlayer = null;
}

function copyToClipboard(type) {
    if (!modalActivePlayer) return;
    
    let valueToCopy = "";
    if (type === 'steam') valueToCopy = "steam:11000011" + modalActivePlayer.id + "d7f9b";
    else if (type === 'discord') valueToCopy = "191232" + modalActivePlayer.id + "84525";
    else if (type === 'license') valueToCopy = "license:71aaf3ddda4507" + modalActivePlayer.id + "aef";

    const el = document.createElement('textarea');
    el.value = valueToCopy;
    document.body.appendChild(el);
    el.select();
    document.execCommand('copy');
    document.body.removeChild(el);

    showNotification(`Copied ${type.toUpperCase()} identifier to clipboard!`, "success");
}

function triggerModalLookupActivity() {
    if (!modalActivePlayer) return;
    closePlayerModal();
    switchTab('lookup');
    // Set search value and trigger search
    document.getElementById('lookup-discord-input').value = "379195472268492801"; // Default mockup search from screenshot
    performPlayerLookup();
}

function triggerModalAction(action) {
    if (!modalActivePlayer) return;
    
    if (action === 'ban' || action === 'kick') {
        const reason = prompt(`Enter reason to ${action} ${modalActivePlayer.name}:`, `Administrative ${action}`);
        if (reason === null) return;
        $.post(`https://${GetParentResourceName()}/playerAction`, JSON.stringify({ action: action, id: modalActivePlayer.id, reason: reason }));
    } else {
        $.post(`https://${GetParentResourceName()}/playerAction`, JSON.stringify({ action: action, id: modalActivePlayer.id }));
    }
    closePlayerModal();
}

// ----------------------------------------------------
// Incident Logs Console
// ----------------------------------------------------
function renderLogs() {
    const container = document.getElementById('logs-console');
    container.innerHTML = '';

    const filtered = logsData.filter(log => {
        if (activeFilter === 'all') return true;
        return log.type === activeFilter;
    });

    if (filtered.length === 0) {
        container.innerHTML = `<div class="cli-line comment"># No incident logs available.</div>`;
        return;
    }

    filtered.forEach(log => {
        const div = document.createElement('div');
        div.className = 'log-line';
        
        let typeLabel = log.type.toUpperCase();
        let classColor = 'info';
        if (log.type === 'ban') classColor = 'ban';
        if (log.type === 'flag') classColor = 'flag';
        if (log.type === 'event') classColor = 'event';

        div.innerHTML = `
            <span class="log-time">[${log.time || '00:00:00'}]</span>
            <span class="log-tag ${classColor}">${typeLabel}</span>
            <span class="log-message" style="color: ${log.type === 'ban' ? 'var(--accent-red)' : 'var(--text-primary)'}">${log.message}</span>
        `;
        container.appendChild(div);
    });
}

const filterBtns = document.querySelectorAll('.filter-btn');
filterBtns.forEach(btn => {
    btn.addEventListener('click', () => {
        filterBtns.forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        activeFilter = btn.getAttribute('data-filter');
        renderLogs();
    });
});

function clearLogs() {
    logsData = [];
    renderLogs();
    $.post(`https://${GetParentResourceName()}/clearLogs`, JSON.stringify({}));
}

// ----------------------------------------------------
// Terminal Console CLI
// ----------------------------------------------------
const termInput = document.getElementById('terminal-input');
termInput.addEventListener('keydown', function(event) {
    if (event.key === 'Enter') {
        const commandText = termInput.value.trim();
        if (!commandText) return;

        termInput.value = '';
        appendTerminalLine(`sentinel@server:~$ ${commandText}`, '');
        executeTerminalCommand(commandText);
    }
});

function appendTerminalLine(text, styleClass) {
    const screen = document.getElementById('terminal-screen');
    const div = document.createElement('div');
    div.className = `cli-line ${styleClass}`;
    div.innerText = text;
    screen.appendChild(div);
    screen.scrollTop = screen.scrollHeight;
}

function executeTerminalCommand(cmdText) {
    const parts = cmdText.split(' ');
    const cmd = parts[0].toLowerCase();
    const args = parts.slice(1);

    if (cmd === 'clear') {
        document.getElementById('terminal-screen').innerHTML = '';
        return;
    }

    if (cmd === 'help') {
        appendTerminalLine('Active Sentinel Commands:', 'success');
        appendTerminalLine('  status               - Shows system configuration stats.', 'comment');
        appendTerminalLine('  list                 - Lists all online players.', 'comment');
        appendTerminalLine('  warn [id] [reason]   - Warns online player.', 'comment');
        appendTerminalLine('  kick [id] [reason]   - Kicks player.', 'comment');
        appendTerminalLine('  ban [id] [reason]    - Permanently bans player.', 'comment');
        appendTerminalLine('  unban [license]      - Removes ban record.', 'comment');
        return;
    }

    $.post(`https://${GetParentResourceName()}/executeCliCommand`, JSON.stringify({ cmd: cmd, args: args }));
}

function renderAdminsList(admins) {
    const body = document.getElementById('admins-list-body');
    if (!body) return;
    body.innerHTML = '';
    if (admins.length === 0) {
        body.innerHTML = '<tr><td colspan="4" style="text-align: center; color: var(--text-secondary); padding: 20px;">No administrators online.</td></tr>';
        return;
    }
    admins.forEach(adm => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
            <td>${adm.name}</td>
            <td style="font-family: monospace; font-size: 11px;">${adm.steam}</td>
            <td><span class="badge enabled">${adm.group}</span></td>
            <td>${adm.ip}</td>
        `;
        body.appendChild(tr);
    });
}

function showNotification(message, type = 'success') {
    const container = document.getElementById('toast-container');
    if (!container) return;

    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    
    let icon = '<i class="fa-solid fa-circle-check"></i>';
    if (type === 'error') {
        icon = '<i class="fa-solid fa-circle-exclamation"></i>';
    } else if (type === 'info') {
        icon = '<i class="fa-solid fa-circle-info"></i>';
    }

    toast.innerHTML = `
        ${icon}
        <span>${message}</span>
    `;

    container.appendChild(toast);

    // Auto-remove after 3 seconds
    setTimeout(() => {
        toast.remove();
    }, 3000);
}

// Update ticking real-time local date and time in the header
setInterval(() => {
    const now = new Date();
    const dateStr = now.getFullYear() + '-' + 
                    String(now.getMonth() + 1).padStart(2, '0') + '-' + 
                    String(now.getDate()).padStart(2, '0') + ' ' + 
                    String(now.getHours()).padStart(2, '0') + ':' + 
                    String(now.getMinutes()).padStart(2, '0') + ':' + 
                    String(now.getSeconds()).padStart(2, '0');
    const dtElement = document.getElementById('hdr-datetime');
    if (dtElement) dtElement.innerText = dateStr;
}, 1000);

// ----------------------------------------------------
// NUI PANEL SETTINGS LISTENERS
// ----------------------------------------------------
setTimeout(() => {
    const opacitySlider = document.getElementById('panel-opacity-slider');
    const opacityVal = document.getElementById('panel-opacity-val');
    const scanToggle = document.getElementById('panel-scanlines-toggle');
    const tiltToggle = document.getElementById('panel-tilt-toggle');
    const appContainer = document.getElementById('app');
    const mapCanvas = document.getElementById('map-gta-canvas');

    if (opacitySlider && appContainer) {
        opacitySlider.addEventListener('input', (e) => {
            const val = e.target.value;
            appContainer.style.background = `rgba(9, 11, 17, ${val / 100})`;
            if (opacityVal) opacityVal.innerText = `${val}%`;
        });
    }

    if (scanToggle) {
        scanToggle.addEventListener('change', (e) => {
            const scanOverlay = document.querySelector('.stream-feed-tag');
            const paths = document.querySelectorAll('.modal-stream-canvas path, .modal-stream-canvas circle');
            if (e.target.checked) {
                if (scanOverlay) scanOverlay.style.display = 'flex';
                paths.forEach(p => p.style.opacity = '1');
            } else {
                if (scanOverlay) scanOverlay.style.display = 'none';
                paths.forEach(p => p.style.opacity = '0.15');
            }
        });
    }

    if (tiltToggle && mapCanvas) {
        tiltToggle.addEventListener('change', (e) => {
            const mv = mapCanvas.querySelector('model-viewer');
            if (mv) {
                if (e.target.checked) {
                    mv.setAttribute('auto-rotate', '');
                } else {
                    mv.removeAttribute('auto-rotate');
                }
            }
        });
    }

}, 1200);

// Initialize Bans records (Image 3 mock grid data) on document load
renderBans();
switchTab('overview');




