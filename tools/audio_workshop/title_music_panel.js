(() => {
  'use strict';
  const tracks = window.TITLE_MUSIC;
  const $ = id => document.getElementById(id);
  const player = $('player');
  let selected = 0, filter = 'Tous', request = 0, tourStart = 0, tourAdvancing = false;
  let favorites = new Set();
  try { favorites = new Set(JSON.parse(localStorage.getItem('catabase-title-favorites-v1') || '[]')); } catch (_) {}
  const safe = text => text.replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const time = seconds => `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2,'0')}`;
  function render() {
    $('cards').innerHTML = tracks.map((track, index) => {
      const hidden = filter === 'Favoris' ? !favorites.has(track.id) : filter !== 'Tous' && track.group !== filter;
      return `<article class="card ${index === selected ? 'active' : ''}" data-track="${track.id}" ${hidden ? 'hidden' : ''}>
        <div class="card-top"><span class="number">${String(index + 1).padStart(2,'0')}</span>${track.pick ? `<span class="badge">${safe(track.pick)}</span>` : ''}<button class="star" data-favorite="${index}" aria-label="Favori : ${safe(track.title)}" aria-pressed="${favorites.has(track.id)}">${favorites.has(track.id) ? '★' : '☆'}</button></div>
        <h3>${safe(track.title)}</h3><p class="author">${safe(track.author)}</p>
        <p class="tags">${safe(track.direction)} · ${safe(track.intensity)}</p>
        <p class="sound">${safe(track.sound)}</p><p class="fit">${safe(track.fit)}</p><p class="watch">${safe(track.watch)}</p>
        <div class="card-footer"><button class="listen" data-play="${index}" aria-label="Écouter ${safe(track.title)}">▶ Écouter</button><a class="source" href="${track.source}" target="_blank" rel="noopener">Fiche de l’auteur ↗</a></div>
        <p class="credit">${safe(track.title)} — ${safe(track.author)} · <a href="https://creativecommons.org/licenses/by/4.0/" target="_blank" rel="noopener">CC BY 4.0</a> · Gratuit avec attribution.</p>
      </article>`;
    }).join('');
    $('empty').hidden = filter !== 'Favoris' || tracks.some(track => favorites.has(track.id));
  }
  function choose(index) {
    selected = (index + tracks.length) % tracks.length;
    const track = tracks[selected];
    player.pause();
    player.src = track.audio;
    $('now-title').textContent = track.title;
    $('now-author').textContent = track.author;
    $('now-fit').textContent = track.sound;
    $('position').textContent = `${String(selected + 1).padStart(2,'0')} / 08`;
    $('moment').textContent = `À ${time(track.moment)}`;
    render();
  }
  async function play(index = selected, offset = 0) {
    const currentRequest = ++request;
    choose(index);
    player.currentTime = offset;
    tourStart = offset;
    tourAdvancing = false;
    $('status').textContent = 'Chargement depuis le site de l’auteur…';
    try {
      await player.play();
      if (currentRequest === request) $('status').textContent = `Lecture : ${tracks[selected].title}`;
    } catch (error) {
      if (currentRequest === request && error.name !== 'AbortError') $('status').textContent = 'Lecture indisponible. Réessaie ou ouvre la fiche de l’auteur.';
    }
  }
  $('cards').addEventListener('click', event => {
    const listen = event.target.closest('[data-play]');
    const star = event.target.closest('[data-favorite]');
    if (listen) void play(Number(listen.dataset.play));
    if (star) {
      const id = tracks[Number(star.dataset.favorite)].id;
      favorites.has(id) ? favorites.delete(id) : favorites.add(id);
      try { localStorage.setItem('catabase-title-favorites-v1', JSON.stringify([...favorites])); } catch (_) {}
      render();
    }
  });
  $('filters').addEventListener('click', event => {
    const button = event.target.closest('[data-filter]');
    if (!button) return;
    filter = button.dataset.filter;
    $('filters').querySelectorAll('button').forEach(item => item.setAttribute('aria-pressed', String(item === button)));
    render();
  });
  $('start').onclick = () => void play();
  $('moment').onclick = () => void play(selected, tracks[selected].moment);
  $('previous').onclick = () => void play(selected - 1);
  $('next').onclick = () => void play(selected + 1);
  $('stop').onclick = () => {
    request++;
    player.pause(); player.currentTime = 0;
    $('tour').checked = false;
    $('status').textContent = 'Lecture arrêtée.';
  };
  $('volume').oninput = () => { player.volume = Number($('volume').value) / 100; };
  player.addEventListener('volumechange', () => {
    const value = Math.round(player.volume * 100);
    $('volume').value = value;
    $('volume-value').textContent = `${value} %`;
  });
  $('loop').onchange = () => {
    player.loop = $('loop').checked;
    if (player.loop) $('tour').checked = false;
  };
  $('tour').onchange = () => {
    if ($('tour').checked) {
      $('loop').checked = player.loop = false;
      void play(selected);
    }
  };
  player.addEventListener('timeupdate', () => {
    if ($('tour').checked && !player.paused && !tourAdvancing && player.currentTime - tourStart >= 40) {
      tourAdvancing = true;
      if (selected === tracks.length - 1) $('stop').click();
      else void play(selected + 1);
    }
  });
  player.addEventListener('playing', () => { $('status').textContent = `Lecture : ${tracks[selected].title}`; });
  player.addEventListener('error', () => { $('status').textContent = 'La source ne répond pas. Réessaie ou ouvre la fiche de l’auteur.'; });
  player.addEventListener('ended', () => {
    if ($('tour').checked && selected < tracks.length - 1) void play(selected + 1);
    else $('status').textContent = 'Morceau terminé.';
  });
  $('copy').onclick = async () => {
    const chosen = tracks.filter(track => favorites.has(track.id));
    if (!chosen.length) { $('copy-status').textContent = 'Ajoute au moins un morceau à tes favoris avec son étoile.'; return; }
    const text = 'Mes favoris pour le titre de Catabase :\n' + chosen.map(track => `${track.title} — ${track.author}\n${track.source}`).join('\n\n');
    try {
      await navigator.clipboard.writeText(text);
      $('copy-status').textContent = `${chosen.length} favori(s) copié(s). Tu peux les coller dans la conversation.`;
      $('copy-fallback').hidden = true;
    } catch (_) {
      $('copy-fallback').hidden = false;
      $('copy-fallback').value = text;
      $('copy-fallback').select();
      $('copy-status').textContent = 'La copie automatique est indisponible. Copie la liste ci-dessous.';
    }
  };
  $('fullscreen').onclick = async () => {
    try { await document.querySelector('.stage').requestFullscreen(); }
    catch (_) { $('status').textContent = 'Le plein écran n’est pas disponible dans ce navigateur.'; }
  };
  window.addEventListener('pagehide', () => player.pause());
  player.volume = 0.25;
  choose(0);
})();
