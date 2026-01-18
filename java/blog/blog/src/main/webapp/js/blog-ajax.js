(function () {
  function asJson(form) {
    const fd = new FormData(form);
    return {
      title: (fd.get('title') || '').toString(),
      postedText: (fd.get('context') || '').toString()
    };
  }

  async function handleSubmit(e) {
    const form = e.target;
    if (!form.matches('form[data-ajax]')) return;
    e.preventDefault();

    const action = form.getAttribute('action') || '';
    const method = (form.getAttribute('data-ajax-method') || 'POST').toUpperCase();

    let url = '/api/posts';
    if (action.match(/^\/posts\/[0-9]+\/edit$/)) {
      const id = action.split('/')[2];
      url = `/api/posts/${id}`;
    }
    if (action.match(/^\/posts\/[0-9]+\/delete$/)) {
      const id = action.split('/')[2];
      url = `/api/posts/${id}`;
    }

    const body = asJson(form);

    const res = await fetch(url, {
      method,
      headers: { 'Content-Type': 'application/json' },
      body: (method === 'DELETE') ? undefined : JSON.stringify(body)
    });

    if (!res.ok) {
      const msg = await res.text();
      alert('API error: ' + msg);
      return;
    }

    // Simple UX: after create/update/delete, go back to posts list.
    window.location.href = '/posts';
  }

  document.addEventListener('submit', handleSubmit);
})();
