window.onload = function () {
  fetch('/posts')
    .then(res => res.json())
    .then(posts => {
      const list = document.getElementById('post-list');
      list.innerHTML = posts.map(post => `
        <div>
          <h3>${post.title}</h3>
          <p>${post.content}</p>
          <small>${new Date(post.created).toLocaleString('ko-KR')}</small>
        </div><hr/>
      `).join('');
    });
}