const horseWindow = document.getElementById('horse-window');
const wildRegisterWindow = document.getElementById('wild-register-window');
const manageWindow = document.getElementById('manage-window');
const stableInventoryWindow = document.getElementById('stable-inventory-window');
const horseCard = document.querySelector('.horse-card');
const wildRegisterCard = document.querySelector('.wild-register-card');
const manageCard = document.querySelector('.manage-card');
const buyButton = document.getElementById('buy');
const wildRegisterConfirm = document.getElementById('wild-register-confirm');
const scaleInputs = document.querySelectorAll('[data-ui-scale]');
const scaleValues = document.querySelectorAll('[data-scale-value]');
const cameraZoom = document.getElementById('camera-zoom');
const horseList = document.getElementById('horse-list');
const wagonList = document.getElementById('wagon-list');
const buyModal = document.getElementById('buy-modal');
const customizePanel = document.getElementById('customize-panel');
const wagonCustomizePanel = document.getElementById('wagon-customize-panel');
const wagonHorsesPanel = document.getElementById('wagon-horses-panel');
const customizeCategories = document.getElementById('customize-categories');
const scaleStorageKey = 'nt_stables_ui_scale_v2';
const baseUiScale = 1.25;
const manageBaseWidth = 560;
const customizeBaseScale = Number(getComputedStyle(document.documentElement).getPropertyValue('--customize-base-scale')) || 1;
const defaultUiScale = 1;
let managedHorses = [];
let managedWagons = [];
let rotatingCamera = false;
let pendingCameraMovementX = 0;
let pendingCameraMovementY = 0;
let cameraMovementFrame = 0;
let selectedManagedHorseId = 0;
let selectedManagedWagonId = 0;
let selectedManageType = 'horse';
let selectedBuyGender = 'male';
let customizationOptions = [];
let selectedCustomizationCategory;
let componentTintTimer = 0;
let componentPreviewTimer = 0;
let wagonCatalog = [];
let selectedWagonModel;
let wagonCustomizationMode = 'buy';
let wagonCustomizationValues = { livery: -1, tint: 0, extra: 0, extras: [], lantern: 0 };
let wagonOriginalCustomization = { livery: -1, tint: 0, extras: [], lantern: 0 };
let wagonCustomizationPrices = { livery: 0, tint: 0, extras: 0, lanterns: 0 };
let ownedHorseCount = 0;
let wagonHorseAssignment = { wagonId: 0, horseCount: 0, assignments: [], horses: [], selectedSlot: 0 };
let stableInventory = { items: [], horse: null, wagon: null };
let auctionHome = { selling: 0, receiving: 0, funds: 0 };
let auctionOwnedHorses = [];
let auctionListings = [];
let auctionHeld = { selling: [], receiving: [], funds: 0 };
let auctionBuyType = 'direct';
let auctionSellType = 'direct';
let selectedAuctionHorseId = 0;

const postNui = (callback, data = {}) => fetch(`https://${GetParentResourceName()}/${callback}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
});

const applyScale = (value) => {
    const maximum = Number(scaleInputs[0].max);
    const scale = Math.min(maximum, Math.max(0.5, Number(value)));
    document.documentElement.style.setProperty('--horse-ui-scale', scale * baseUiScale);
    document.documentElement.style.setProperty('--manage-ui-scale', scale);
    document.documentElement.style.setProperty('--customize-ui-scale', scale * customizeBaseScale);
    document.documentElement.style.setProperty('--manage-panel-width', `${manageBaseWidth * scale}px`);
    document.documentElement.style.setProperty('--manage-content-height', `${window.innerHeight / scale}px`);
    scaleInputs.forEach((input) => { input.value = scale.toFixed(2); });
    scaleValues.forEach((output) => { output.textContent = `${Math.round(scale * 100)}%`; });
    localStorage.setItem(scaleStorageKey, scale);
};

const updateScaleLimit = () => {
    const horseVisible = horseWindow.classList.contains('visible');
    const wildRegisterVisible = wildRegisterWindow.classList.contains('visible');
    const card = horseVisible ? horseCard : wildRegisterVisible ? wildRegisterCard : manageCard;
    const cardBaseScale = horseVisible || wildRegisterVisible ? baseUiScale : manageCard.classList.contains('customizing') ? customizeBaseScale : 1;
    const widthScale = (window.innerWidth * 0.94) / ((horseVisible || wildRegisterVisible ? card.offsetWidth : manageBaseWidth) * cardBaseScale);
    const heightScale = (window.innerHeight * 0.94) / (card.offsetHeight * cardBaseScale);
    const viewportMax = horseVisible || wildRegisterVisible ? Math.min(2, widthScale, heightScale) : Math.min(2, widthScale);
    const maxScale = Math.max(0.5, Math.floor((viewportMax + Number.EPSILON) / 0.05) * 0.05);

    scaleInputs.forEach((input) => { input.max = maxScale.toFixed(2); });
    applyScale(scaleInputs[0].value);
};

const savedScale = Number(localStorage.getItem(scaleStorageKey));
applyScale(savedScale >= 0.5 ? savedScale : defaultUiScale);

const closeHorse = () => postNui('closeHorse');
const closeWildHorseRegistration = () => postNui('closeWildHorseRegistration');
const closeHorseManager = () => postNui('closeHorseManager');
const closeStableInventory = () => postNui('closeStableInventory');

const renderStableInventory = (inventory) => {
    stableInventory = inventory;
    const itemList = document.getElementById('stable-inventory-items');
    const emptyMessage = document.getElementById('stable-inventory-empty');
    const fee = document.getElementById('stable-inventory-fee');
    itemList.replaceChildren();
    emptyMessage.hidden = inventory.items.length > 0;

    fee.hidden = Number(inventory.storageFee) <= 0;
    fee.textContent = `Storage fee: $${Number(inventory.storageFee).toFixed(2)} per hour`;

    inventory.items.forEach((item) => {
        const row = document.createElement('label');
        row.className = 'stable-inventory-item';
        const checkbox = document.createElement('input');
        checkbox.type = 'checkbox';
        checkbox.value = item.slot;
        checkbox.addEventListener('change', updateStableTransferButtons);
        const image = document.createElement('img');
        image.src = `nui://rsg-inventory/html/images/${item.image}`;
        image.alt = '';
        const name = document.createElement('span');
        name.textContent = `${item.label || item.name} - ${item.amount}`;
        row.append(checkbox, image, name);
        itemList.appendChild(row);
    });
    updateStableTransferButtons();
};

const updateStableTransferButtons = () => {
    const selected = [...document.querySelectorAll('#stable-inventory-items input:checked')];
    const selectedItems = selected.map((checkbox) => stableInventory.items.find((item) => Number(item.slot) === Number(checkbox.value)));
    const selectedWeight = selectedItems.reduce((weight, item) => weight + (Number(item.weight) * Number(item.amount)), 0);
    const updateButton = (buttonId, destination) => {
        const button = document.getElementById(buttonId);
        button.disabled = !destination || selected.length === 0 || selected.length > destination.freeSlots
            || Number(destination.currentWeight) + selectedWeight > Number(destination.maxWeight);
        button.title = destination
            ? `${destination.label}: ${(destination.currentWeight / 1000).toFixed(1)} / ${(destination.maxWeight / 1000).toFixed(1)} kg, ${destination.freeSlots} free slots`
            : 'No active inventory is available.';
    };
    updateButton('transfer-stable-horse', stableInventory.horse);
    updateButton('transfer-stable-wagon', stableInventory.wagon);
};

const transferStableInventory = async (destination) => {
    const slots = [...document.querySelectorAll('#stable-inventory-items input:checked')].map((checkbox) => Number(checkbox.value));
    const response = await postNui('transferStableInventory', { destination, slots });
    const result = await response.json();
    if (result.success) renderStableInventory(result);
};

const closeManageModals = () => {
    document.getElementById('rename-modal').hidden = true;
    document.getElementById('sell-modal').hidden = true;
    document.getElementById('riding-warning-modal').hidden = true;
    document.getElementById('wagon-stats-modal').hidden = true;
};

const showManageMain = (visible) => {
    document.querySelectorAll('[data-manage-main]').forEach((element) => {
        element.hidden = !visible;
    });
    if (visible) {
        const hasHorse = selectedManageType === 'horse' && selectedManagedHorseId > 0;
        const hasWagon = selectedManageType === 'wagon' && selectedManagedWagonId > 0;
        document.querySelectorAll('[data-owned-horse]').forEach((element) => { element.hidden = !hasHorse; });
        document.querySelectorAll('[data-owned-wagon]').forEach((element) => { element.hidden = !hasWagon; });
    }
    customizePanel.hidden = visible;
    wagonCustomizePanel.hidden = true;
    wagonHorsesPanel.hidden = true;
};

const auctionSections = ['auction-home', 'auction-buy', 'auction-sell', 'auction-results', 'auction-tracked', 'auction-held'];
const showAuctionSection = (section) => {
    auctionSections.forEach((id) => { document.getElementById(id).hidden = id !== section; });
    document.getElementById('auction-back').textContent = section === 'auction-home' ? 'Return to Stable' : 'Back';
};

const wildModifierText = (horse, stat) => {
    const modifier = Number(horse.wildModifiers && horse.wildModifiers[stat]);
    if (!horse.wild || !modifier) return '';
    return ` (${modifier > 0 ? '+' : ''}${modifier} Wild)`;
};

const renderHorseStat = (horse, stat) => {
    const maximum = Number(horse.maximumStat);
    const current = Math.max(0, Math.min(maximum, Number(horse[stat])));
    const capable = Math.max(current, Math.min(maximum, Number(horse.maximumStats[stat])));
    const modifier = horse.wild ? Number(horse.wildModifiers && horse.wildModifiers[stat]) || 0 : 0;
    const modifiedDots = Math.min(current, Math.abs(modifier));
    const dots = document.getElementById(`${stat}-dots`);

    document.getElementById(stat).textContent = current;
    dots.replaceChildren();

    for (let value = 1; value <= maximum; value += 1) {
        const dot = document.createElement('span');
        if (value <= modifiedDots) dot.className = `stat-dot ${modifier < 0 ? 'negative' : 'positive'}`;
        else if (value <= current) dot.className = 'stat-dot current';
        else if (value <= capable) dot.className = 'stat-dot capable';
        else dot.className = 'stat-dot unavailable';
        dots.appendChild(dot);
    }
};

const renderAuctionHorseDetails = (container, horse, extraLines = []) => {
    container.replaceChildren();
    if (!horse) return;
    const heading = document.createElement('h2');
    heading.textContent = horse.name;
    const summary = document.createElement('p');
    summary.textContent = `${horse.breed} • ${horse.gender === 'male' ? 'Gelding' : 'Mare'} • Level ${horse.level}`;
    const stats = document.createElement('div');
    stats.className = 'auction-stats-grid';
    ['health', 'stamina', 'agility', 'speed', 'acceleration', 'strength'].forEach((stat) => {
        const label = document.createElement('span');
        label.textContent = stat.charAt(0).toUpperCase() + stat.slice(1);
        const value = document.createElement('strong');
        value.textContent = `${horse.stats[stat]}${wildModifierText(horse, stat)}`;
        stats.append(label, value);
    });
    const carryLabel = document.createElement('span');
    carryLabel.textContent = 'Carry Weight';
    const carryValue = document.createElement('strong');
    carryValue.textContent = `${Number(horse.carryWeight)} kg`;
    const pullLabel = document.createElement('span');
    pullLabel.textContent = 'Pull Weight';
    const pullValue = document.createElement('strong');
    pullValue.textContent = `${Number(horse.pullWeight)} kg`;
    stats.append(carryLabel, carryValue, pullLabel, pullValue);
    container.append(heading, summary, stats);
    extraLines.forEach((line) => {
        const text = document.createElement('p');
        text.textContent = line;
        container.append(text);
    });
};

const formatAuctionTime = (seconds) => {
    seconds = Math.max(0, Number(seconds) || 0);
    const days = Math.floor(seconds / 86400);
    const hours = Math.floor((seconds % 86400) / 3600);
    return days > 0 ? `${days}d ${hours}h remaining` : `${hours}h ${Math.floor((seconds % 3600) / 60)}m remaining`;
};

const renderAuctionHome = () => {
    const held = document.getElementById('auction-held-button');
    const heldCount = Number(auctionHome.selling) + Number(auctionHome.receiving);
    held.disabled = heldCount === 0 && Number(auctionHome.funds) <= 0;
    held.textContent = heldCount > 0 ? `Horses Held (${heldCount})` : 'Horses Held';
    const tracked = document.getElementById('auction-tracked-button');
    tracked.disabled = Number(auctionHome.tracking) <= 0;
    tracked.textContent = Number(auctionHome.tracking) > 0 ? `Tracked Auctions (${auctionHome.tracking})` : 'Tracked Auctions';
    showAuctionSection('auction-home');
};

const renderAuctionSellHorses = () => {
    const list = document.getElementById('auction-sell-list');
    list.replaceChildren();
    auctionOwnedHorses.forEach((horse) => {
        const button = document.createElement('button');
        button.className = 'horse-list-button stable-slot';
        button.type = 'button';
        button.textContent = `${horse.name} • ${horse.breed}`;
        button.addEventListener('click', () => {
            selectedAuctionHorseId = Number(horse.id);
            list.querySelectorAll('button').forEach((entry) => entry.classList.remove('active'));
            button.classList.add('active');
            document.getElementById('auction-listing-form').hidden = false;
            renderAuctionHorseDetails(document.getElementById('auction-sell-details'), horse);
            postNui('auctionPreviewOwnedHorse', { horseId: horse.id });
        });
        list.append(button);
    });
    if (!auctionOwnedHorses.length) {
        const empty = document.createElement('p');
        empty.textContent = 'You have no horses available to list.';
        list.append(empty);
    }
};

const getAuctionFilters = () => {
    const filters = {
        minimumLevel: document.getElementById('auction-min-level').value,
        maximumLevel: document.getElementById('auction-max-level').value,
        minimumPrice: document.getElementById('auction-min-price').value,
        maximumPrice: document.getElementById('auction-max-price').value,
    };
    document.querySelectorAll('#auction-stat-filter-grid input').forEach((input) => { filters[input.id.replace('auction-', '').replaceAll('-', '_')] = input.value; });
    return filters;
};

const renderAuctionListings = () => {
    const list = document.getElementById('auction-result-list');
    const details = document.getElementById('auction-horse-details');
    const actions = document.getElementById('auction-purchase-actions');
    list.replaceChildren(); details.replaceChildren(); actions.replaceChildren();
    auctionListings.forEach((listing, listingIndex) => {
        const button = document.createElement('button');
        button.className = 'horse-list-button stable-slot';
        button.type = 'button';
        button.dataset.listingIndex = listingIndex;
        button.textContent = `${listing.horse.name} • ${listing.horse.breed}`;
        button.addEventListener('click', () => {
            list.querySelectorAll('button').forEach((entry) => entry.classList.remove('active'));
            button.classList.add('active');
            postNui('auctionPreviewListing', { listingId: listing.id });
            const price = listing.listingType === 'direct' ? `Price: $${Number(listing.price).toFixed(2)}` : `Current bid: $${Number(listing.currentBid || listing.price).toFixed(2)}`;
            renderAuctionHorseDetails(details, listing.horse, [price, `Seller: ${listing.sellerName}`, formatAuctionTime(listing.secondsLeft)]);
            actions.replaceChildren();
            if (listing.listingType === 'direct') {
                const buy = document.createElement('button');
                buy.type = 'button'; buy.textContent = `Buy Horse - $${Number(listing.price).toFixed(2)}`;
                buy.addEventListener('click', async () => {
                    buy.disabled = true;
                    const response = await postNui('buyAuctionHorse', { listingId: listing.id });
                    const result = await response.json();
                    if (result.success) { auctionListings = auctionListings.filter((entry) => entry.id !== listing.id); renderAuctionListings(); }
                    else buy.disabled = false;
                });
                actions.append(buy);
            } else {
                const bid = document.createElement('input');
                bid.type = 'number'; bid.min = listing.minimumBid; bid.step = '0.01'; bid.value = Number(listing.minimumBid).toFixed(2);
                const place = document.createElement('button');
                place.type = 'button'; place.textContent = 'Place Bid';
                place.addEventListener('click', async () => {
                    place.disabled = true;
                    const response = await postNui('placeAuctionBid', { listingId: listing.id, amount: bid.value });
                    const result = await response.json();
                    if (result.success) {
                        const wasTracked = listing.tracked === true;
                        listing.tracked = true;
                        if (!wasTracked) auctionHome.tracking = Number(auctionHome.tracking) + 1;
                        document.getElementById('auction-view-horses').click();
                    }
                    else place.disabled = false;
                });
                const track = document.createElement('button');
                track.type = 'button';
                track.textContent = listing.tracked ? 'Tracking Auction' : 'Track Auction';
                track.disabled = listing.tracked === true;
                track.addEventListener('click', async () => {
                    track.disabled = true;
                    const response = await postNui('trackAuction', { listingId: listing.id });
                    const result = await response.json();
                    if (result.success) {
                        listing.tracked = true;
                        track.textContent = 'Tracking Auction';
                        auctionHome.tracking = Number(auctionHome.tracking) + 1;
                    } else track.disabled = false;
                });
                actions.append(bid, place, track);
            }
        });
        list.append(button);
    });
    if (!auctionListings.length) {
        const empty = document.createElement('p'); empty.textContent = 'No matching horses are currently listed.'; list.append(empty);
    } else {
        list.querySelector('button').click();
        list.focus();
    }
};

const renderTrackedAuctions = () => {
    const list = document.getElementById('auction-tracked-list');
    const details = document.getElementById('auction-tracked-details');
    const actions = document.getElementById('auction-tracked-actions');
    list.replaceChildren(); details.replaceChildren(); actions.replaceChildren();
    auctionListings.forEach((listing) => {
        const button = document.createElement('button');
        button.className = 'horse-list-button stable-slot';
        button.type = 'button';
        button.textContent = `${listing.horse.name} • $${Number(listing.currentBid || listing.price).toFixed(2)}`;
        button.addEventListener('click', () => {
            list.querySelectorAll('button').forEach((entry) => entry.classList.remove('active'));
            button.classList.add('active');
            postNui('auctionPreviewListing', { listingId: listing.id });
            renderAuctionHorseDetails(details, listing.horse, [
                `Current bid: $${Number(listing.currentBid || listing.price).toFixed(2)}`,
                `Seller: ${listing.sellerName}`,
                formatAuctionTime(listing.secondsLeft),
            ]);
            actions.replaceChildren();
            const bid = document.createElement('input');
            bid.type = 'number'; bid.min = listing.minimumBid; bid.step = '0.01'; bid.value = Number(listing.minimumBid).toFixed(2);
            const place = document.createElement('button');
            place.type = 'button'; place.textContent = 'Place Bid';
            place.addEventListener('click', async () => {
                place.disabled = true;
                const response = await postNui('placeAuctionBid', { listingId: listing.id, amount: bid.value });
                const result = await response.json();
                if (result.success) document.querySelector('[data-auction-home="tracked"]').click();
                else place.disabled = false;
            });
            const untrack = document.createElement('button');
            untrack.type = 'button'; untrack.className = 'secondary'; untrack.textContent = 'Stop Tracking';
            untrack.addEventListener('click', async () => {
                untrack.disabled = true;
                const response = await postNui('untrackAuction', { listingId: listing.id });
                const result = await response.json();
                if (result.success) {
                    auctionListings = auctionListings.filter((entry) => entry.id !== listing.id);
                    auctionHome.tracking = auctionListings.length;
                    renderTrackedAuctions();
                } else untrack.disabled = false;
            });
            actions.append(bid, place, untrack);
        });
        list.append(button);
    });
    if (!auctionListings.length) {
        const empty = document.createElement('p'); empty.textContent = 'No active auctions are being tracked.'; list.append(empty);
    }
};

const renderHeldHorses = () => {
    const selling = document.getElementById('auction-selling-list');
    const receiving = document.getElementById('auction-receiving-list');
    const details = document.getElementById('auction-held-details');
    const actions = document.getElementById('auction-held-actions');
    selling.replaceChildren(); receiving.replaceChildren(); details.replaceChildren(); actions.replaceChildren();
    auctionHome.selling = auctionHeld.selling.length;
    auctionHome.receiving = auctionHeld.receiving.length;
    auctionHome.funds = auctionHeld.funds;
    document.getElementById('auction-funds').textContent = `$${Number(auctionHeld.funds).toFixed(2)}`;
    document.getElementById('auction-collect-funds').disabled = Number(auctionHeld.funds) <= 0;

    const selectHeld = (record, type, button) => {
        selling.querySelectorAll('button').forEach((entry) => entry.classList.remove('active'));
        receiving.querySelectorAll('button').forEach((entry) => entry.classList.remove('active'));
        button.classList.add('active');
        postNui('auctionPreviewHeldHorse', { heldId: record.id, heldType: type });
        renderAuctionHorseDetails(details, record.horse, type === 'selling'
            ? [`${record.listingType === 'direct' ? 'Direct Sale' : 'Auction'} • $${Number(record.currentBid || record.price).toFixed(2)}`, formatAuctionTime(record.secondsLeft)]
            : [`Waiting reason: ${record.reason.replaceAll('_', ' ')}`]);
        actions.replaceChildren();
        const action = document.createElement('button');
        action.type = 'button'; action.className = type === 'selling' ? 'danger' : '';
        action.textContent = type === 'selling' ? 'Cancel Listing' : 'Add to Stable';
        action.addEventListener('click', async () => {
            action.disabled = true;
            const response = await postNui(type === 'selling' ? 'cancelAuctionListing' : 'receiveAuctionHorse', type === 'selling' ? { listingId: record.id } : { receiveId: record.id });
            const result = await response.json();
            if (result.success) {
                auctionHeld = result.held;
                if (result.horses) auctionOwnedHorses = result.horses;
                renderHeldHorses();
            }
            else action.disabled = false;
        });
        actions.append(action);
    };
    auctionHeld.selling.forEach((record) => {
        const button = document.createElement('button'); button.className = 'horse-list-button stable-slot'; button.type = 'button'; button.textContent = `${record.horse.name} • ${record.listingType}`;
        button.addEventListener('click', () => selectHeld(record, 'selling', button)); selling.append(button);
    });
    auctionHeld.receiving.forEach((record) => {
        const button = document.createElement('button'); button.className = 'horse-list-button stable-slot'; button.type = 'button'; button.textContent = `${record.horse.name} • Waiting`;
        button.addEventListener('click', () => selectHeld(record, 'receiving', button)); receiving.append(button);
    });
    if (!auctionHeld.selling.length) { const empty = document.createElement('p'); empty.textContent = 'No horses currently selling.'; selling.append(empty); }
    if (!auctionHeld.receiving.length) { const empty = document.createElement('p'); empty.textContent = 'No horses waiting for your stable.'; receiving.append(empty); }
};

const renderWagonHorseAssignment = () => {
    const diagram = document.getElementById('wagon-horse-diagram');
    diagram.querySelectorAll('.wagon-horse-slot').forEach((button) => button.remove());
    diagram.className = `wagon-horse-diagram horse-count-${wagonHorseAssignment.horseCount}`;

    for (let slot = 1; slot <= wagonHorseAssignment.horseCount; slot += 1) {
        const assignment = wagonHorseAssignment.assignments.find((horse) => Number(horse.slot) === slot);
        const button = document.createElement('button');
        button.className = `wagon-horse-slot wagon-horse-slot-${slot}`;
        button.classList.toggle('assigned', Boolean(assignment));
        button.classList.toggle('selected', wagonHorseAssignment.selectedSlot === slot);
        button.type = 'button';
        button.title = assignment ? `Slot ${slot}: ${assignment.name}` : `Assign slot ${slot}`;

        const image = document.createElement('img');
        image.src = 'imgs/Horse.png';
        image.alt = '';
        const label = document.createElement('span');
        label.textContent = assignment ? assignment.name : `Slot ${slot}`;
        button.append(image, label);
        button.addEventListener('click', () => {
            wagonHorseAssignment.selectedSlot = slot;
            renderWagonHorseAssignment();
        });
        diagram.append(button);
    }

    const horseList = document.getElementById('wagon-horse-list');
    const help = document.getElementById('wagon-horse-help');
    horseList.replaceChildren();
    if (!wagonHorseAssignment.selectedSlot) {
        help.textContent = 'Select a wagon horse slot.';
    } else {
        help.textContent = `Choose a horse for slot ${wagonHorseAssignment.selectedSlot}.`;
    }

    wagonHorseAssignment.horses.forEach((horse) => {
        const assignment = wagonHorseAssignment.assignments.find((assignedHorse) => Number(assignedHorse.id) === Number(horse.id));
        const button = document.createElement('button');
        button.className = 'wagon-horse-list-button';
        button.classList.toggle('assigned', Boolean(assignment));
        button.type = 'button';
        const name = document.createElement('span');
        name.textContent = horse.name;
        const slot = document.createElement('small');
        slot.textContent = assignment ? `Slot ${assignment.slot}` : '';
        button.append(name, slot);
        button.addEventListener('click', () => {
            if (!wagonHorseAssignment.selectedSlot) {
                help.textContent = 'Select a wagon horse slot before choosing a horse.';
                return;
            }
            postNui('setWagonHorse', {
                wagonId: wagonHorseAssignment.wagonId,
                slot: wagonHorseAssignment.selectedSlot,
                horseId: assignment && Number(assignment.slot) === wagonHorseAssignment.selectedSlot ? null : horse.id,
            });
        });
        horseList.append(button);
    });
};

const closeBuyModal = () => {
    buyModal.hidden = true;
};

const updateCustomizationPrice = () => {
    const price = customizationOptions.reduce((total, category) => {
        const styleChanged = category.currentValue !== Number(category.originalValue);
        const tintChanged = category.tints.tint0 !== category.originalTints.tint0
            || category.tints.tint1 !== category.originalTints.tint1
            || category.tints.tint2 !== category.originalTints.tint2;
        return total + (styleChanged || tintChanged ? Number(category.price) : 0);
    }, 0);

    document.getElementById('customize-price').textContent = `$${price.toFixed(2)}`;
};

const updateComponentTintInputs = () => {
    if (!selectedCustomizationCategory) return;

    document.querySelectorAll('[data-component-tint]').forEach((input) => {
        input.value = selectedCustomizationCategory.tints[input.dataset.componentTint];
        document.querySelector(`[data-component-tint-value="${input.dataset.componentTint}"]`).textContent = Number(input.value) === 255 ? 'Disabled' : `Color ${input.value}`;
    });
};

const openCustomizationCategory = (category) => {
    selectedCustomizationCategory = category;
    customizeCategories.replaceChildren();

    const selectedModel = category.models
        ? category.models.findIndex((model) => model.values
            ? model.values.includes(category.currentValue)
            : category.currentValue >= model.first && category.currentValue <= model.last) + 1
        : category.currentValue;

    const row = document.createElement('label');
    row.className = 'customize-category';
    const heading = document.createElement('span');
    const value = document.createElement('output');
    const slider = document.createElement('input');
    slider.type = 'range';
    slider.min = 0;
    slider.max = category.models ? category.models.length : category.maximum;
    slider.step = 1;
    slider.value = selectedModel;

    const variationRow = document.createElement('label');
    variationRow.className = 'customize-category';
    const variationHeading = document.createElement('span');
    variationHeading.textContent = 'Variation';
    const variationValue = document.createElement('output');
    const variationSlider = document.createElement('input');
    variationSlider.type = 'range';
    variationSlider.min = 1;
    variationSlider.step = 1;

    const getVariations = (model) => {
        if (!model) return [];
        if (model.values) return model.values.map(Number);

        const variations = [];
        for (let variation = Number(model.first); variation <= Number(model.last); variation += 1) {
            variations.push(variation);
        }
        return variations;
    };

    const updateModel = (selection, useRepresentative) => {
        const model = category.models && category.models[Number(selection) - 1];
        const variations = getVariations(model);
        heading.textContent = model ? `${category.label} - ${model.name}` : category.label;
        value.textContent = Number(selection) === 0 ? category.defaultLabel : category.models ? `Model ${selection}` : `Style ${selection}`;

        if (!model) {
            if (useRepresentative) category.currentValue = 0;
            variationSlider.max = 1;
            variationSlider.value = 1;
            variationSlider.disabled = true;
            variationValue.textContent = 'None';
            return;
        }

        if (useRepresentative || !variations.includes(category.currentValue)) {
            category.currentValue = Number(model.value);
        }

        const variation = variations.indexOf(category.currentValue) + 1;
        variationSlider.max = variations.length;
        variationSlider.value = variation;
        variationSlider.disabled = variations.length <= 1;
        variationValue.textContent = `Variation ${variation} of ${variations.length}`;
    };

    const previewComponent = () => {
        clearTimeout(componentPreviewTimer);
        componentPreviewTimer = setTimeout(async () => {
            const response = await postNui('customizeHorseComponent', { category: category.key, value: category.currentValue });
            const result = await response.json();
            if (result.tints) {
                category.tints = { ...result.tints };
                updateComponentTintInputs();
                updateCustomizationPrice();
            }
            componentPreviewTimer = 0;
        }, 100);
    };

    updateModel(selectedModel, false);

    slider.addEventListener('input', () => {
        updateModel(slider.value, true);
        updateCustomizationPrice();
        previewComponent();
    });

    variationSlider.addEventListener('input', () => {
        const model = category.models && category.models[Number(slider.value) - 1];
        const variations = getVariations(model);
        category.currentValue = variations[Number(variationSlider.value) - 1];
        variationValue.textContent = `Variation ${variationSlider.value} of ${variations.length}`;
        updateCustomizationPrice();
        previewComponent();
    });

    row.append(heading, value, slider);
    variationRow.append(variationHeading, variationValue, variationSlider);
    customizeCategories.append(row, variationRow);
    document.getElementById('component-customize-title').textContent = `${category.label} Customization`;
    document.getElementById('customize-menu').hidden = true;
    document.getElementById('component-customize-panel').hidden = false;
    updateComponentTintInputs();
    updateCustomizationPrice();
    requestAnimationFrame(updateScaleLimit);
};

const renderCustomization = (data) => {
    const customizeMenu = document.getElementById('customize-menu');
    customizeMenu.replaceChildren();
    customizationOptions = data.categories.map((category) => ({
        ...category,
        currentValue: Number(category.value),
        tints: { ...category.tints },
        originalTints: { ...category.originalTints },
    }));

    customizationOptions.forEach((category) => {
        const button = document.createElement('button');
        button.className = 'customize-menu-button';
        button.type = 'button';
        const label = document.createElement('strong');
        label.textContent = category.label;
        const description = document.createElement('span');
        description.textContent = `Choose a ${category.label.toLowerCase()} and edit its colors.`;
        button.append(label, description);
        button.addEventListener('click', () => openCustomizationCategory(category));
        customizeMenu.append(button);
    });

    selectedCustomizationCategory = undefined;
    customizeMenu.hidden = false;
    document.getElementById('component-customize-panel').hidden = true;
    updateCustomizationPrice();
};

const updateWagonCustomizationControls = () => {
    const wagon = wagonCatalog.find((entry) => entry.model === selectedWagonModel);
    if (!wagon) return;

    const wagonIndex = wagonCatalog.indexOf(wagon);
    document.getElementById('wagon-model-name').textContent = wagon.label;
    document.getElementById('wagon-model-type').textContent = wagon.category.charAt(0).toUpperCase() + wagon.category.slice(1);
    document.getElementById('wagon-model-weight').textContent = `${(Number(wagon.maxWeight) / 1000).toFixed(0)} kg`;
    document.getElementById('wagon-model-slots').textContent = wagon.slots;
    const wagonHorseCount = document.getElementById('wagon-model-horses');
    const hasEnoughHorses = ownedHorseCount >= Number(wagon.horseCount);
    wagonHorseCount.textContent = wagon.horseCount;
    wagonHorseCount.classList.toggle('enough', hasEnoughHorses);
    wagonHorseCount.classList.toggle('insufficient', !hasEnoughHorses);
    document.getElementById('wagon-model-price').textContent = `$${Number(wagon.price).toFixed(2)}`;
    document.getElementById('wagon-model-number').textContent = `${wagonIndex + 1} / ${wagonCatalog.length}`;
    document.getElementById('wagon-model-scroll').value = wagonIndex + 1;
    document.getElementById('wagon-model-previous').disabled = wagonIndex === 0;
    document.getElementById('wagon-model-next').disabled = wagonIndex === wagonCatalog.length - 1;

    const controls = [
        ['wagon-livery', 'wagon-livery-value', wagon.livery, wagonCustomizationValues.livery, (value) => value === -1 ? 'Default' : `Style ${value}`],
        ['wagon-tint', 'wagon-tint-value', wagon.tint, wagonCustomizationValues.tint, (value) => `Color ${value}`],
        ['wagon-extra', 'wagon-extra-value', wagon.extras, wagonCustomizationValues.extra, (value) => value === 0 ? 'Extras Added' : `Style ${value}`],
        ['wagon-lantern', 'wagon-lantern-value', wagon.lanterns, wagonCustomizationValues.lantern, (value, index) => value === 0 ? 'None' : `Style ${index}`],
    ];

    controls.forEach(([inputId, outputId, values, selectedValue, formatValue]) => {
        const input = document.getElementById(inputId);
        const selectedIndex = Math.max(0, values.indexOf(selectedValue));
        input.max = Math.max(0, values.length - 1);
        input.value = selectedIndex;
        document.getElementById(outputId).textContent = formatValue(values[selectedIndex], selectedIndex);
    });

    document.getElementById('wagon-lantern-option').hidden = wagon.lanterns.length <= 1;

    const selectedExtra = Number(wagonCustomizationValues.extra);
    const enabledExtras = wagonCustomizationValues.extras.map(Number);
    document.getElementById('wagon-extra-option').hidden = wagon.extras.length <= 1;
    document.getElementById('wagon-extra-enabled').checked = selectedExtra > 0 && enabledExtras.includes(selectedExtra);
    document.getElementById('wagon-extra-enabled').disabled = selectedExtra === 0;
    document.getElementById('wagon-extra-list').textContent = enabledExtras.length
        ? `Added: ${enabledExtras.map((extra) => `Extra ${extra}`).join(', ')}`
        : 'Added: None';

    let price = wagonCustomizationMode === 'buy' ? Number(wagon.price) : 0;
    if (wagonCustomizationValues.livery !== wagonOriginalCustomization.livery) price += Number(wagonCustomizationPrices.livery);
    if (wagonCustomizationValues.tint !== wagonOriginalCustomization.tint) price += Number(wagonCustomizationPrices.tint);
    price += wagonCustomizationValues.extras.filter((extra) => !wagonOriginalCustomization.extras.includes(extra)).length
        * Number(wagonCustomizationPrices.extras);
    if (wagonCustomizationValues.lantern !== wagonOriginalCustomization.lantern) price += Number(wagonCustomizationPrices.lanterns);

    document.getElementById('wagon-price').textContent = `$${price.toFixed(2)}`;
};

const renderWagonCustomization = (data) => {
    wagonCatalog = data.wagons;
    selectedWagonModel = data.selected.model;
    wagonCustomizationMode = data.mode;
    wagonCustomizationPrices = data.prices;
    ownedHorseCount = Number(data.ownedHorseCount);
    wagonCustomizationValues = {
        livery: Number(data.selected.livery),
        tint: Number(data.selected.tint),
        extra: Number(data.selected.extra),
        extras: Array.isArray(data.selected.extras) ? data.selected.extras.map(Number) : [],
        lantern: data.selected.lantern,
    };
    wagonOriginalCustomization = wagonCustomizationMode === 'buy' ? {
        livery: wagonCatalog.find((wagon) => wagon.model === selectedWagonModel).livery[0],
        tint: wagonCatalog.find((wagon) => wagon.model === selectedWagonModel).tint[0],
        extras: [],
        lantern: 0,
    } : {
        livery: wagonCustomizationValues.livery,
        tint: wagonCustomizationValues.tint,
        extras: [...wagonCustomizationValues.extras],
        lantern: wagonCustomizationValues.lantern,
    };

    const modelScroll = document.getElementById('wagon-model-scroll');
    modelScroll.max = wagonCatalog.length;

    document.getElementById('wagon-model-browser').hidden = data.mode !== 'buy';
    document.getElementById('wagon-name').parentElement.hidden = data.mode !== 'buy';
    document.getElementById('wagon-name').value = data.selected.name;
    document.getElementById('wagon-price-row').hidden = false;
    document.getElementById('wagon-price-label').textContent = data.mode === 'buy' ? 'Purchase Price' : 'Changes Price';
    document.getElementById('wagon-customize-title').textContent = data.mode === 'buy' ? 'Buy Wagon' : 'Customize Wagon';
    document.getElementById('wagon-customize-save').textContent = data.mode === 'buy' ? 'Buy Wagon' : 'Save Customization';
    updateWagonCustomizationControls();
};

const selectWagonCatalogIndex = async (wagonIndex) => {
    const wagon = wagonCatalog[wagonIndex];
    if (wagonCustomizationMode !== 'buy' || !wagon || wagon.model === selectedWagonModel) return;

    const response = await postNui('selectWagonModel', { model: wagon.model });
    const result = await response.json();
    if (!result.success) return;

    selectedWagonModel = wagon.model;
    wagonCustomizationValues = {
        livery: Number(result.livery),
        tint: Number(result.tint),
        extra: Number(result.extra),
        extras: [],
        lantern: result.lantern,
    };
    wagonOriginalCustomization = {
        livery: wagonCustomizationValues.livery,
        tint: wagonCustomizationValues.tint,
        extras: [],
        lantern: 0,
    };
    document.getElementById('wagon-name').value = wagon.label;
    updateWagonCustomizationControls();
};

document.getElementById('wagon-model-scroll').addEventListener('change', (event) => {
    selectWagonCatalogIndex(Number(event.target.value) - 1);
});

document.getElementById('wagon-model-previous').addEventListener('click', () => {
    selectWagonCatalogIndex(wagonCatalog.findIndex((wagon) => wagon.model === selectedWagonModel) - 1);
});

document.getElementById('wagon-model-next').addEventListener('click', () => {
    selectWagonCatalogIndex(wagonCatalog.findIndex((wagon) => wagon.model === selectedWagonModel) + 1);
});

const selectManagedHorse = (horseId, updatePreview = true) => {
    const selectedHorse = managedHorses.find((horse) => horse.id === horseId);
    document.querySelectorAll('[data-owned-horse]').forEach((element) => { element.hidden = !selectedHorse; });
    document.querySelectorAll('[data-owned-wagon]').forEach((element) => { element.hidden = true; });
    if (!selectedHorse) {
        selectedManagedHorseId = 0;
        return;
    }

    selectedManageType = 'horse';
    selectedManagedHorseId = horseId;
    selectedManagedWagonId = 0;

    document.querySelectorAll('.horse-list-button').forEach((button) => {
        button.classList.toggle('active', Number(button.dataset.horseId) === horseId);
    });

    document.getElementById('managed-horse-name').textContent = selectedHorse.name;
    document.getElementById('managed-horse-breed').textContent = selectedHorse.breed;
    document.getElementById('camera-help').textContent = 'Hold right mouse and drag in any direction to orbit around the horse.';
    document.querySelectorAll('.occupied-wagon-slot').forEach((button) => button.classList.remove('active'));
    if (updatePreview) postNui('selectManagedHorse', { horseId });
};

const selectManagedWagon = (wagonId, updatePreview = true) => {
    const selectedWagon = managedWagons.find((wagon) => wagon.id === wagonId);
    document.querySelectorAll('[data-owned-wagon]').forEach((element) => { element.hidden = !selectedWagon; });
    document.querySelectorAll('[data-owned-horse]').forEach((element) => { element.hidden = true; });
    if (!selectedWagon) {
        selectedManagedWagonId = 0;
        return;
    }

    selectedManageType = 'wagon';
    selectedManagedWagonId = wagonId;
    selectedManagedHorseId = 0;
    document.querySelectorAll('.occupied-wagon-slot').forEach((button) => {
        button.classList.toggle('active', Number(button.dataset.wagonId) === wagonId);
    });
    document.querySelectorAll('.horse-list-button').forEach((button) => button.classList.remove('active'));
    document.getElementById('managed-wagon-name').textContent = selectedWagon.name;
    document.getElementById('managed-wagon-model').textContent = selectedWagon.needsRepair
        ? `${selectedWagon.label} • Needs repair`
        : selectedWagon.label;
    const repairButton = document.querySelector('[data-wagon-action="repair"]');
    repairButton.hidden = !selectedWagon.needsRepair;
    repairButton.textContent = `Repair Wagon - $${Number(selectedWagon.repairPrice).toFixed(2)}`;
    document.getElementById('camera-help').textContent = 'Hold right mouse and drag in any direction to orbit around the wagon.';
    if (updatePreview) postNui('selectManagedWagon', { wagonId });
};

const createEmptySlot = (slotNumber, slotType) => {
    const slot = document.createElement('div');
    slot.className = 'stable-slot empty-slot';
    const name = document.createElement('span');
    name.textContent = `Slot ${slotNumber}`;
    const status = document.createElement('small');
    status.textContent = 'Empty';
    slot.append(name, status);
    if (slotType === 'wagon') {
        slot.classList.add('wagon-empty-slot');
        const buy = document.createElement('button');
        buy.className = 'slot-buy-button';
        buy.type = 'button';
        buy.textContent = 'Buy';
        buy.addEventListener('click', () => postNui('openWagonPurchase'));
        slot.append(buy);
    }
    return slot;
};

const renderManagedStable = (horses, selectedHorseId, wagons, selectedWagonId, horseSlots, wagonSlots, debt) => {
    managedHorses = horses;
    managedWagons = wagons;
    horseList.replaceChildren();
    wagonList.replaceChildren();

    for (let slotNumber = 1; slotNumber <= horseSlots.total; slotNumber += 1) {
        const horse = horses[slotNumber - 1];
        if (!horse) {
            horseList.append(createEmptySlot(slotNumber, 'horse'));
            continue;
        }

        const button = document.createElement('button');
        button.className = 'horse-list-button stable-slot';
        button.type = 'button';
        button.dataset.horseId = horse.id;

        const name = document.createElement('span');
        name.textContent = horse.name;
        const breed = document.createElement('small');
        breed.textContent = horse.isWagonHorse ? `${horse.breed} • Wagon Horse` : horse.breed;

        button.append(name, breed);

        if (horse.active) {
            const active = document.createElement('em');
            active.textContent = 'Active';
            button.append(active);
        }

        button.addEventListener('click', () => selectManagedHorse(horse.id));
        horseList.append(button);
    }

    for (let slotNumber = 1; slotNumber <= wagonSlots.total; slotNumber += 1) {
        const wagon = wagons[slotNumber - 1];
        if (!wagon) {
            wagonList.append(createEmptySlot(slotNumber, 'wagon'));
            continue;
        }

        const slot = document.createElement('button');
        slot.className = 'stable-slot occupied-wagon-slot';
        slot.type = 'button';
        slot.dataset.wagonId = wagon.id;
        const name = document.createElement('span');
        name.textContent = wagon.name;
        const model = document.createElement('small');
        model.textContent = wagon.needsRepair
            ? `${wagon.label} • Needs repair`
            : wagon.ready ? wagon.label : `${wagon.label} • Horses needed`;
        slot.append(name, model);
        if (wagon.active) {
            const active = document.createElement('em');
            active.textContent = 'Active';
            slot.append(active);
        }
        slot.addEventListener('click', () => selectManagedWagon(wagon.id));
        wagonList.append(slot);
    }

    document.getElementById('horse-slot-count').textContent = `${horseSlots.used} / ${horseSlots.total}`;
    document.getElementById('wagon-slot-count').textContent = `${wagonSlots.used} / ${wagonSlots.total}`;
    document.getElementById('stable-debt').textContent = `$${Number(debt).toFixed(2)}`;

    const buyHorseSlot = document.getElementById('buy-horse-slot');
    const sellHorseSlot = document.getElementById('sell-horse-slot');
    const buyWagonSlot = document.getElementById('buy-wagon-slot');
    const sellWagonSlot = document.getElementById('sell-wagon-slot');
    buyHorseSlot.textContent = `Buy Horse Slot - $${Number(horseSlots.buyPrice).toFixed(2)}`;
    sellHorseSlot.textContent = `Sell Empty Slot - $${Number(horseSlots.sellPrice).toFixed(2)}`;
    sellHorseSlot.hidden = !horseSlots.canSell;
    buyWagonSlot.textContent = `Buy Wagon Slot - $${Number(wagonSlots.buyPrice).toFixed(2)}`;
    sellWagonSlot.textContent = `Sell Empty Slot - $${Number(wagonSlots.sellPrice).toFixed(2)}`;
    sellWagonSlot.hidden = !wagonSlots.canSell;

    const selectedId = horses.some((horse) => horse.id === Number(selectedHorseId))
        ? Number(selectedHorseId)
        : 0;
    const selectedWagon = wagons.some((wagon) => wagon.id === Number(selectedWagonId))
        ? Number(selectedWagonId)
        : 0;

    if (selectedWagon || (!selectedId && selectedManageType === 'wagon' && wagons[0])) {
        selectManagedWagon(selectedWagon || wagons[0].id, false);
    } else if (selectedId || horses[0]) {
        selectManagedHorse(selectedId || horses[0].id, false);
    } else if (wagons[0]) {
        selectManagedWagon(wagons[0].id, false);
    } else {
        selectManagedHorse(0, false);
        document.querySelectorAll('[data-owned-wagon]').forEach((element) => { element.hidden = true; });
    }
};

window.addEventListener('message', (event) => {
    if (event.data.action === 'openHorseAuction') {
        auctionHome = event.data.home;
        auctionOwnedHorses = event.data.horses || [];
        document.getElementById('auction-panel').hidden = false;
        document.getElementById('manage-eyebrow').textContent = 'Stable Market';
        document.getElementById('manage-title').textContent = 'Horse Auction';
        showManageMain(false);
        customizePanel.hidden = true;
        wagonCustomizePanel.hidden = true;
        wagonHorsesPanel.hidden = true;
        document.getElementById('auction-panel').hidden = false;
        renderAuctionHome();
        return;
    }

    if (event.data.action === 'refreshAuctionHeld') {
        auctionHeld = event.data.held || { selling: [], receiving: [], funds: 0 };
        auctionHome.selling = auctionHeld.selling.length;
        auctionHome.receiving = auctionHeld.receiving.length;
        renderHeldHorses();
        showAuctionSection('auction-held');
        return;
    }

    if (event.data.action === 'returnFromHorseAuction') {
        document.getElementById('auction-panel').hidden = true;
        document.getElementById('manage-eyebrow').textContent = 'Stable Management';
        document.getElementById('manage-title').textContent = 'Manage Stable';
        showManageMain(true);
        renderManagedStable(event.data.horses, event.data.selectedHorseId, event.data.wagons, event.data.selectedWagonId, event.data.horseSlots, event.data.wagonSlots, event.data.debt);
        return;
    }

    if (event.data.action === 'openStableInventory') {
        horseWindow.classList.remove('visible');
        wildRegisterWindow.classList.remove('visible');
        manageWindow.classList.remove('visible');
        renderStableInventory(event.data.inventory);
        stableInventoryWindow.classList.add('visible');
        stableInventoryWindow.setAttribute('aria-hidden', 'false');
        return;
    }

    if (event.data.action === 'closeStableInventory') {
        stableInventoryWindow.classList.remove('visible');
        stableInventoryWindow.setAttribute('aria-hidden', 'true');
        return;
    }

    if (event.data.action === 'closeWildHorseRegistration') {
        wildRegisterWindow.classList.remove('visible');
        wildRegisterWindow.setAttribute('aria-hidden', 'true');
        wildRegisterConfirm.disabled = false;
        return;
    }

    if (event.data.action === 'closeHorse') {
        horseWindow.classList.remove('visible');
        horseWindow.setAttribute('aria-hidden', 'true');
        closeBuyModal();
        if (event.data.returnToManager) {
            manageWindow.classList.add('visible');
            manageWindow.setAttribute('aria-hidden', 'false');
            requestAnimationFrame(updateScaleLimit);
        }
        return;
    }

    if (event.data.action === 'closeHorseManager') {
        manageWindow.classList.remove('visible', 'rotating');
        manageWindow.setAttribute('aria-hidden', 'true');
        rotatingCamera = false;
        manageCard.classList.remove('customizing');
        document.getElementById('auction-panel').hidden = true;
        closeManageModals();
        showManageMain(true);
        return;
    }

    if (event.data.action === 'openHorseManager') {
        horseWindow.classList.remove('visible');
        wildRegisterWindow.classList.remove('visible');
        cameraZoom.value = event.data.cameraZoom;
        manageCard.classList.remove('customizing');
        closeManageModals();
        document.getElementById('auction-panel').hidden = true;
        document.getElementById('manage-eyebrow').textContent = 'Stable Management';
        document.getElementById('manage-title').textContent = 'Manage Stable';
        showManageMain(true);
        renderManagedStable(event.data.horses, event.data.selectedHorseId, event.data.wagons, event.data.selectedWagonId, event.data.horseSlots, event.data.wagonSlots, event.data.debt);
        manageWindow.classList.add('visible');
        manageWindow.setAttribute('aria-hidden', 'false');
        requestAnimationFrame(updateScaleLimit);
        return;
    }

    if (event.data.action === 'openHorseCustomization') {
        horseWindow.classList.remove('visible');
        wildRegisterWindow.classList.remove('visible');
        horseWindow.setAttribute('aria-hidden', 'true');
        closeBuyModal();
        closeManageModals();
        cameraZoom.value = event.data.cameraZoom;
        manageCard.classList.add('customizing');
        document.getElementById('manage-eyebrow').textContent = 'Stable Workshop';
        document.getElementById('manage-title').textContent = 'Customize Horse';
        document.getElementById('customize-horse-name').textContent = event.data.name;
        document.getElementById('customize-horse-details').textContent = `${event.data.breed} - ${event.data.gender === 'male' ? 'Gelding' : 'Mare'}`;
        document.getElementById('customize-save').textContent = 'Purchase Customization';
        renderCustomization(event.data);
        document.getElementById('customize-menu').hidden = false;
        document.getElementById('component-customize-panel').hidden = true;
        showManageMain(false);
        manageWindow.classList.add('visible');
        manageWindow.setAttribute('aria-hidden', 'false');
        requestAnimationFrame(updateScaleLimit);
        return;
    }

    if (event.data.action === 'closeHorseCustomization') {
        manageCard.classList.remove('customizing');
        document.getElementById('manage-eyebrow').textContent = 'Stable Management';
        document.getElementById('manage-title').textContent = 'Manage Stable';
        showManageMain(true);
        requestAnimationFrame(updateScaleLimit);
        return;
    }

    if (event.data.action === 'openWagonCustomization') {
        horseWindow.classList.remove('visible');
        wildRegisterWindow.classList.remove('visible');
        horseWindow.setAttribute('aria-hidden', 'true');
        closeBuyModal();
        closeManageModals();
        cameraZoom.value = event.data.cameraZoom;
        manageCard.classList.add('customizing');
        document.getElementById('manage-eyebrow').textContent = 'Stable Workshop';
        document.getElementById('manage-title').textContent = event.data.mode === 'buy' ? 'Buy Wagon' : 'Customize Wagon';
        renderWagonCustomization(event.data);
        showManageMain(false);
        customizePanel.hidden = true;
        wagonCustomizePanel.hidden = false;
        manageWindow.classList.add('visible');
        manageWindow.setAttribute('aria-hidden', 'false');
        requestAnimationFrame(updateScaleLimit);
        return;
    }

    if (event.data.action === 'closeWagonCustomization') {
        manageCard.classList.remove('customizing');
        document.getElementById('manage-eyebrow').textContent = 'Stable Management';
        document.getElementById('manage-title').textContent = 'Manage Stable';
        showManageMain(true);
        requestAnimationFrame(updateScaleLimit);
        return;
    }

    if (event.data.action === 'openWagonHorseAssignment') {
        wagonHorseAssignment = {
            wagonId: Number(event.data.wagonId),
            horseCount: Number(event.data.horseCount),
            assignments: event.data.assignments || [],
            horses: event.data.horses || [],
            selectedSlot: 0,
        };
        manageCard.classList.add('customizing');
        document.getElementById('manage-eyebrow').textContent = 'Stable Workshop';
        document.getElementById('manage-title').textContent = 'Assign Wagon Horses';
        document.getElementById('wagon-horses-title').textContent = event.data.wagonName;
        showManageMain(false);
        customizePanel.hidden = true;
        wagonCustomizePanel.hidden = true;
        wagonHorsesPanel.hidden = false;
        renderWagonHorseAssignment();
        requestAnimationFrame(updateScaleLimit);
        return;
    }

    if (event.data.action === 'refreshWagonHorseAssignment') {
        wagonHorseAssignment.assignments = event.data.assignments || [];
        wagonHorseAssignment.horses = event.data.horses || [];
        renderWagonHorseAssignment();
        return;
    }

    if (event.data.action === 'closeWagonHorseAssignment') {
        wagonHorseAssignment = { wagonId: 0, horseCount: 0, assignments: [], horses: [], selectedSlot: 0 };
        manageCard.classList.remove('customizing');
        document.getElementById('manage-eyebrow').textContent = 'Stable Management';
        document.getElementById('manage-title').textContent = 'Manage Stable';
        showManageMain(true);
        requestAnimationFrame(updateScaleLimit);
        return;
    }

    if (event.data.action === 'openWagonStats') {
        document.getElementById('wagon-stats-name').textContent = event.data.name;
        document.getElementById('wagon-stats-description').textContent = event.data.description;
        document.getElementById('wagon-stats-model').textContent = event.data.label;
        document.getElementById('wagon-stats-horses').textContent = event.data.horseCount;
        document.getElementById('wagon-stats-slots').textContent = event.data.slots;
        document.getElementById('wagon-stats-current-weight').textContent = `${(Number(event.data.currentWeight) / 1000).toFixed(0)} kg`;
        document.getElementById('wagon-stats-weight').textContent = `${(Number(event.data.maxWeight) / 1000).toFixed(0)} kg`;
        document.getElementById('wagon-stats-price').textContent = `$${Number(event.data.price).toFixed(2)}`;
        document.getElementById('wagon-stats-modal').hidden = false;
        return;
    }

    if (event.data.action === 'refreshManagedHorses') {
        renderManagedStable(event.data.horses, event.data.selectedHorseId, event.data.wagons, event.data.selectedWagonId, event.data.horseSlots, event.data.wagonSlots, event.data.debt);
        closeManageModals();
        return;
    }

    if (event.data.action === 'openWildHorseRegistration') {
        const horse = event.data.horse;
        const quote = event.data.quote;
        horseWindow.classList.remove('visible');
        manageWindow.classList.remove('visible');
        closeBuyModal();

        document.getElementById('wild-register-breed').textContent = horse.breed;
        document.getElementById('wild-register-gender').textContent = horse.gender === 'male' ? 'Male' : 'Female';
        document.getElementById('wild-register-fee').textContent = `$${Number(quote.registrationFee).toFixed(2)}`;
        document.getElementById('wild-register-slot-fee').textContent = `$${Number(quote.slotFee).toFixed(2)}`;
        document.getElementById('wild-register-total').textContent = `$${Number(quote.total).toFixed(2)}`;
        document.getElementById('wild-register-slot-row').hidden = !quote.slotRequired;
        document.getElementById('wild-register-slot-note').hidden = !quote.slotRequired;
        document.getElementById('wild-register-name').value = '';
        wildRegisterConfirm.textContent = quote.slotRequired ? 'Register & Buy Slot' : 'Register Horse';
        wildRegisterConfirm.disabled = false;

        wildRegisterWindow.classList.add('visible');
        wildRegisterWindow.setAttribute('aria-hidden', 'false');
        document.getElementById('wild-register-name').focus();
        requestAnimationFrame(updateScaleLimit);
        return;
    }

    if (event.data.action !== 'openHorse') return;

    const horse = event.data.horse;
    closeBuyModal();
    manageWindow.classList.remove('visible');
    wildRegisterWindow.classList.remove('visible');
    document.getElementById('breed').textContent = horse.name || horse.breed;
    document.getElementById('breed-summary').textContent = horse.breed;
    document.getElementById('tame-level').textContent = horse.tameLevel;
    ['health', 'stamina', 'agility', 'speed', 'acceleration', 'strength'].forEach((stat) => renderHorseStat(horse, stat));
    document.getElementById('carry-weight').textContent = `${horse.carryWeight} kg`;
    document.getElementById('pull-weight').textContent = `${horse.pullWeight} kg`;
    document.getElementById('price').textContent = `$${Number(horse.price).toFixed(2)}`;

    buyButton.textContent = 'Buy';
    buyButton.hidden = !horse.showBuy;
    horseWindow.classList.add('visible');
    horseWindow.setAttribute('aria-hidden', 'false');
    requestAnimationFrame(updateScaleLimit);
});

document.getElementById('close').addEventListener('click', closeHorse);
document.getElementById('leave').addEventListener('click', closeHorse);
document.getElementById('wild-register-close').addEventListener('click', closeWildHorseRegistration);
document.getElementById('wild-register-cancel').addEventListener('click', closeWildHorseRegistration);
document.getElementById('open-horse-auction').addEventListener('click', () => postNui('openHorseAuction'));

['health', 'stamina', 'agility', 'speed', 'acceleration', 'strength'].forEach((stat) => {
    const label = stat.charAt(0).toUpperCase() + stat.slice(1);
    ['minimum', 'maximum'].forEach((range) => {
        const field = document.createElement('label');
        field.textContent = `${range === 'minimum' ? 'Min' : 'Max'} ${label}`;
        const input = document.createElement('input');
        input.id = `auction-${range}-${stat}`; input.type = 'number'; input.min = '0'; input.max = '9';
        field.append(input); document.getElementById('auction-stat-filter-grid').append(field);
    });
});

document.querySelectorAll('[data-auction-home]').forEach((button) => button.addEventListener('click', async () => {
    const section = button.dataset.auctionHome;
    if (section === 'buy') showAuctionSection('auction-buy');
    if (section === 'sell') { selectedAuctionHorseId = 0; renderAuctionSellHorses(); document.getElementById('auction-listing-form').hidden = true; showAuctionSection('auction-sell'); }
    if (section === 'held') {
        const response = await postNui('getHeldHorses'); const result = await response.json();
        auctionHeld = result.held; renderHeldHorses(); showAuctionSection('auction-held');
    }
    if (section === 'tracked') {
        const response = await postNui('getTrackedAuctions'); const result = await response.json();
        auctionListings = result.listings || [];
        auctionHome.tracking = auctionListings.length;
        renderTrackedAuctions(); showAuctionSection('auction-tracked');
    }
}));

document.querySelectorAll('[data-auction-type]').forEach((button) => button.addEventListener('click', () => {
    auctionBuyType = button.dataset.auctionType;
    document.querySelectorAll('[data-auction-type]').forEach((entry) => entry.classList.toggle('active', entry === button));
}));

document.querySelectorAll('[data-auction-sell-type]').forEach((button) => button.addEventListener('click', () => {
    auctionSellType = button.dataset.auctionSellType;
    document.querySelectorAll('[data-auction-sell-type]').forEach((entry) => entry.classList.toggle('active', entry === button));
    document.getElementById('auction-price-label').firstChild.textContent = auctionSellType === 'direct' ? 'Sale Price' : 'Starting Bid';
}));

document.getElementById('auction-list-days').addEventListener('input', (event) => {
    document.getElementById('auction-listing-fee').textContent = `Listing fee: $${Math.max(0, Number(event.target.value)).toFixed(2)}`;
});

document.getElementById('auction-create-listing').addEventListener('click', async () => {
    const button = document.getElementById('auction-create-listing'); button.disabled = true;
    const response = await postNui('createAuctionListing', { horseId: selectedAuctionHorseId, listingType: auctionSellType, price: document.getElementById('auction-list-price').value, days: document.getElementById('auction-list-days').value });
    const result = await response.json(); button.disabled = false;
    if (result.success) auctionOwnedHorses = auctionOwnedHorses.filter((horse) => horse.id !== selectedAuctionHorseId);
});

document.getElementById('auction-view-horses').addEventListener('click', async () => {
    const response = await postNui('getAuctionListings', { listingType: auctionBuyType, filters: getAuctionFilters() });
    const result = await response.json();
    auctionListings = result.listings || [];
    showAuctionSection('auction-results');
    renderAuctionListings();
});

document.getElementById('auction-result-list').addEventListener('keydown', (event) => {
    if (event.key !== 'ArrowUp' && event.key !== 'ArrowDown') return;
    const buttons = [...document.querySelectorAll('#auction-result-list button[data-listing-index]')];
    if (!buttons.length) return;
    event.preventDefault();
    const selectedIndex = buttons.findIndex((button) => button.classList.contains('active'));
    const movement = event.key === 'ArrowDown' ? 1 : -1;
    const nextIndex = Math.max(0, Math.min(buttons.length - 1, (selectedIndex < 0 ? 0 : selectedIndex) + movement));
    buttons[nextIndex].click();
    buttons[nextIndex].focus();
});

document.getElementById('auction-collect-funds').addEventListener('click', async () => {
    const response = await postNui('collectAuctionFunds'); const result = await response.json();
    if (result.success) { auctionHeld.funds = 0; renderHeldHorses(); }
});

document.getElementById('auction-back').addEventListener('click', () => {
    if (!document.getElementById('auction-home').hidden) postNui('closeHorseAuction');
    else renderAuctionHome();
});
document.getElementById('manage-close').addEventListener('click', closeHorseManager);
document.getElementById('manage-leave').addEventListener('click', closeHorseManager);
document.getElementById('stable-inventory-close').addEventListener('click', closeStableInventory);
document.getElementById('transfer-stable-horse').addEventListener('click', () => transferStableInventory('horse'));
document.getElementById('transfer-stable-wagon').addEventListener('click', () => transferStableInventory('wagon'));
document.getElementById('wagon-horses-back').addEventListener('click', () => postNui('closeWagonHorseAssignment'));
document.getElementById('rename-cancel').addEventListener('click', closeManageModals);
document.getElementById('sell-cancel').addEventListener('click', closeManageModals);
document.getElementById('riding-warning-cancel').addEventListener('click', closeManageModals);
document.getElementById('riding-warning-confirm').addEventListener('click', () => {
    document.getElementById('riding-warning-modal').hidden = true;
    postNui('managedHorseAction', { action: 'setRiding', horseId: selectedManagedHorseId });
});
document.getElementById('wagon-stats-close').addEventListener('click', closeManageModals);
scaleInputs.forEach((input) => {
    input.addEventListener('input', () => applyScale(input.value));
});
cameraZoom.addEventListener('input', () => postNui('horseCameraZoom', { zoom: Number(cameraZoom.value) }));
window.addEventListener('resize', updateScaleLimit);

buyButton.addEventListener('click', () => {
    const nameInput = document.getElementById('buy-name');
    nameInput.value = '';
    selectedBuyGender = 'male';
    document.querySelectorAll('[data-buy-gender]').forEach((button) => {
        button.classList.toggle('active', button.dataset.buyGender === selectedBuyGender);
    });
    buyModal.hidden = false;
    nameInput.focus();
});

document.querySelectorAll('[data-buy-gender]').forEach((button) => {
    button.addEventListener('click', () => {
        selectedBuyGender = button.dataset.buyGender;
        document.querySelectorAll('[data-buy-gender]').forEach((genderButton) => {
            genderButton.classList.toggle('active', genderButton === button);
        });
    });
});

document.getElementById('buy-cancel').addEventListener('click', closeBuyModal);
document.getElementById('buy-confirm').addEventListener('click', async () => {
    const button = document.getElementById('buy-confirm');
    const name = document.getElementById('buy-name').value.trim();
    if (!name) return;

    button.disabled = true;
    const response = await postNui('buyHorse', {
        name,
        gender: selectedBuyGender,
    });
    await response.json();
    button.disabled = false;
});

wildRegisterConfirm.addEventListener('click', async () => {
    const name = document.getElementById('wild-register-name').value.trim();
    if (!name) return;

    wildRegisterConfirm.disabled = true;
    const response = await postNui('registerWildHorse', { name });
    const result = await response.json();
    if (!result.success) wildRegisterConfirm.disabled = false;
});

document.querySelectorAll('[data-horse-action]').forEach((button) => {
    button.addEventListener('click', async () => {
        const action = button.dataset.horseAction;
        const selectedHorse = managedHorses.find((horse) => horse.id === selectedManagedHorseId);
        if (!selectedHorse) return;

        if (action === 'rename') {
            selectedManageType = 'horse';
            const renameInput = document.getElementById('rename-input');
            renameInput.maxLength = 32;
            renameInput.value = selectedHorse.name;
            document.getElementById('rename-title').textContent = 'Rename Horse';
            document.getElementById('rename-label').textContent = 'Horse Name';
            document.getElementById('rename-modal').hidden = false;
            renameInput.focus();
            renameInput.select();
            return;
        }

        if (action === 'sell') {
            selectedManageType = 'horse';
            const response = await postNui('getManagedHorseSellPrice', { horseId: selectedManagedHorseId });
            const result = await response.json();
            if (!result.success) return;

            document.getElementById('sell-title').textContent = 'Sell Horse';
            document.getElementById('sell-object-name').textContent = result.name;
            document.getElementById('sell-price').textContent = `$${Number(result.price).toFixed(2)}`;
            document.getElementById('sell-modal').hidden = false;
            return;
        }

        if (action === 'setRiding' && selectedHorse.isWagonHorse) {
            document.getElementById('riding-warning-name').textContent = selectedHorse.name;
            document.getElementById('riding-warning-modal').hidden = false;
            return;
        }

        postNui('managedHorseAction', { action, horseId: selectedManagedHorseId });
    });
});

document.querySelectorAll('[data-wagon-action]').forEach((button) => {
    button.addEventListener('click', async () => {
        const action = button.dataset.wagonAction;
        const selectedWagon = managedWagons.find((wagon) => wagon.id === selectedManagedWagonId);
        if (!selectedWagon) return;

        if (action === 'rename') {
            selectedManageType = 'wagon';
            const renameInput = document.getElementById('rename-input');
            renameInput.maxLength = 100;
            renameInput.value = selectedWagon.name;
            document.getElementById('rename-title').textContent = 'Rename Wagon';
            document.getElementById('rename-label').textContent = 'Wagon Name';
            document.getElementById('rename-modal').hidden = false;
            renameInput.focus();
            renameInput.select();
            return;
        }

        if (action === 'sell') {
            selectedManageType = 'wagon';
            const response = await postNui('getManagedWagonSellPrice', { wagonId: selectedManagedWagonId });
            const result = await response.json();
            if (!result.success) return;

            document.getElementById('sell-title').textContent = 'Sell Wagon';
            document.getElementById('sell-object-name').textContent = result.name;
            document.getElementById('sell-price').textContent = `$${Number(result.price).toFixed(2)}`;
            document.getElementById('sell-modal').hidden = false;
            return;
        }

        postNui('managedWagonAction', { action, wagonId: selectedManagedWagonId });
    });
});

['wagon-livery', 'wagon-tint', 'wagon-extra', 'wagon-lantern'].forEach((inputId) => {
    document.getElementById(inputId).addEventListener('input', () => {
        const wagon = wagonCatalog.find((entry) => entry.model === selectedWagonModel);
        if (!wagon) return;

        wagonCustomizationValues.livery = wagon.livery[Number(document.getElementById('wagon-livery').value)];
        wagonCustomizationValues.tint = wagon.tint[Number(document.getElementById('wagon-tint').value)];
        wagonCustomizationValues.extra = wagon.extras[Number(document.getElementById('wagon-extra').value)];
        wagonCustomizationValues.lantern = wagon.lanterns[Number(document.getElementById('wagon-lantern').value)];
        updateWagonCustomizationControls();
        postNui('previewWagonCustomization', wagonCustomizationValues);
    });
});

document.getElementById('wagon-extra-enabled').addEventListener('change', () => {
    const extra = Number(wagonCustomizationValues.extra);
    if (extra === 0) return;

    if (document.getElementById('wagon-extra-enabled').checked) {
        if (!wagonCustomizationValues.extras.includes(extra)) wagonCustomizationValues.extras.push(extra);
    } else {
        wagonCustomizationValues.extras = wagonCustomizationValues.extras.filter((enabledExtra) => enabledExtra !== extra);
    }

    updateWagonCustomizationControls();
    postNui('previewWagonCustomization', wagonCustomizationValues);
});

const cancelWagonCustomization = () => postNui('cancelWagonCustomization', {
    horseId: selectedManagedHorseId,
    wagonId: selectedManagedWagonId,
});

document.getElementById('wagon-customize-cancel').addEventListener('click', cancelWagonCustomization);
document.getElementById('wagon-customize-save').addEventListener('click', async () => {
    const button = document.getElementById('wagon-customize-save');
    const name = document.getElementById('wagon-name').value.trim();
    if (wagonCustomizationMode === 'buy' && !name) return;

    button.disabled = true;
    const response = await postNui('saveWagonCustomization', { name });
    await response.json();
    button.disabled = false;
});

[
    ['buy-horse-slot', 'horse', 'buy'],
    ['sell-horse-slot', 'horse', 'sell'],
    ['buy-wagon-slot', 'wagon', 'buy'],
    ['sell-wagon-slot', 'wagon', 'sell'],
].forEach(([buttonId, slotType, action]) => {
    document.getElementById(buttonId).addEventListener('click', async (event) => {
        const button = event.currentTarget;
        button.disabled = true;
        const response = await postNui('changeStableSlots', {
            slotType,
            action,
            selectedHorseId: selectedManagedHorseId,
            selectedWagonId: selectedManagedWagonId,
        });
        const result = await response.json();
        if (result.success) {
            renderManagedStable(result.horses, result.selectedHorseId, result.wagons, result.selectedWagonId, result.horseSlots, result.wagonSlots, result.debt);
            closeManageModals();
        }
        button.disabled = false;
    });
});

document.getElementById('rename-confirm').addEventListener('click', async () => {
    const name = document.getElementById('rename-input').value.trim();
    if (!name) return;

    const response = selectedManageType === 'wagon'
        ? await postNui('renameManagedWagon', { wagonId: selectedManagedWagonId, name })
        : await postNui('renameManagedHorse', { horseId: selectedManagedHorseId, name });
    const result = await response.json();
    if (result.success) closeManageModals();
});

document.getElementById('sell-confirm').addEventListener('click', async () => {
    const sellButton = document.getElementById('sell-confirm');
    sellButton.disabled = true;
    const response = selectedManageType === 'wagon'
        ? await postNui('sellManagedWagon', { wagonId: selectedManagedWagonId })
        : await postNui('sellManagedHorse', { horseId: selectedManagedHorseId });
    await response.json();
    sellButton.disabled = false;
});

document.getElementById('customize-cancel').addEventListener('click', () => postNui('cancelHorseCustomization'));
document.getElementById('component-customize-back').addEventListener('click', () => {
    document.getElementById('component-customize-panel').hidden = true;
    document.getElementById('customize-menu').hidden = false;
    requestAnimationFrame(updateScaleLimit);
});
document.querySelectorAll('[data-component-tint]').forEach((input) => {
    input.addEventListener('input', () => {
        if (!selectedCustomizationCategory) return;

        const category = selectedCustomizationCategory;
        category.tints[input.dataset.componentTint] = Number(input.value);
        document.querySelector(`[data-component-tint-value="${input.dataset.componentTint}"]`).textContent = Number(input.value) === 255 ? 'Disabled' : `Color ${input.value}`;
        updateCustomizationPrice();

        clearTimeout(componentTintTimer);
        componentTintTimer = setTimeout(() => {
            postNui('customizeComponentTint', {
                category: category.key,
                ...category.tints,
            });
            componentTintTimer = 0;
        }, 100);
    });
});
document.getElementById('customize-save').addEventListener('click', async () => {
    const button = document.getElementById('customize-save');
    button.disabled = true;
    const response = await postNui('saveHorseCustomization');
    await response.json();
    button.disabled = false;
});

document.addEventListener('contextmenu', (event) => {
    if (manageWindow.classList.contains('visible')) event.preventDefault();
});

document.addEventListener('pointerdown', (event) => {
    if (event.button !== 2 || !manageWindow.classList.contains('visible')) return;
    rotatingCamera = true;
    manageWindow.classList.add('rotating');
});

document.addEventListener('pointerup', (event) => {
    if (event.button !== 2) return;
    rotatingCamera = false;
    manageWindow.classList.remove('rotating');
});

document.addEventListener('pointermove', (event) => {
    if (!rotatingCamera) return;

    pendingCameraMovementX += event.movementX;
    pendingCameraMovementY += event.movementY;
    if (cameraMovementFrame) return;

    cameraMovementFrame = requestAnimationFrame(() => {
        postNui('rotateHorseCamera', {
            movementX: pendingCameraMovementX,
            movementY: pendingCameraMovementY,
        });
        pendingCameraMovementX = 0;
        pendingCameraMovementY = 0;
        cameraMovementFrame = 0;
    });
});

document.addEventListener('keyup', (event) => {
    if (event.key !== 'Escape') return;
    if (!document.getElementById('wagon-stats-modal').hidden) {
        closeManageModals();
        return;
    }
    if (!buyModal.hidden) {
        closeBuyModal();
        return;
    }
    if (!wagonCustomizePanel.hidden) {
        cancelWagonCustomization();
        return;
    }
    if (!customizePanel.hidden) {
        postNui('cancelHorseCustomization');
        return;
    }
    if (wildRegisterWindow.classList.contains('visible')) {
        closeWildHorseRegistration();
        return;
    }
    if (stableInventoryWindow.classList.contains('visible')) {
        closeStableInventory();
        return;
    }
    if (!document.getElementById('auction-panel').hidden) {
        postNui('closeHorseAuction');
        return;
    }
    if (horseWindow.classList.contains('visible')) closeHorse();
    if (manageWindow.classList.contains('visible')) closeHorseManager();
});
