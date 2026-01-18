import React from 'react';

export default function App() {
  const [posts, setPosts] = React.useState([]);
  const [title, setTitle] = React.useState('');
  const [postedText, setPostedText] = React.useState('');
  const [error, setError] = React.useState('');

  async function loadPosts() {
    const res = await fetch('/api/posts');
    const data = await res.json();
    setPosts(Array.isArray(data) ? data : []);
  }

  React.useEffect(() => { loadPosts(); }, []);

  async function createPost(e) {
    e.preventDefault();
    setError('');
    const res = await fetch('/api/posts', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ title, postedText })
    });
    if (!res.ok) {
      setError(await res.text());
      return;
    }
    setTitle('');
    setPostedText('');
    await loadPosts();
  }

  return (
    <div style={{ maxWidth: 900, margin: '24px auto', fontFamily: 'system-ui, sans-serif' }}>
      <h1>Blog (React)</h1>
      <p style={{ color: '#555' }}>
        This is a tiny React UI that talks to <code>/api/posts</code>.
      </p>

      <form onSubmit={createPost} style={{ display: 'grid', gap: 8, marginBottom: 16 }}>
        <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Title" />
        <textarea rows={4} value={postedText} onChange={(e) => setPostedText(e.target.value)} placeholder="Text" />
        <button type="submit">Create</button>
        {error ? <pre style={{ color: 'crimson', whiteSpace: 'pre-wrap' }}>{error}</pre> : null}
      </form>

      <h2>Posts</h2>
      <ul>
        {posts.map((p) => (
          <li key={p.postId} style={{ marginBottom: 10 }}>
            <b>{p.title}</b>
            <div style={{ color: '#666', fontSize: 12 }}>{p.postedDate}</div>
            <div>{p.postedText}</div>
          </li>
        ))}
      </ul>
    </div>
  );
}
