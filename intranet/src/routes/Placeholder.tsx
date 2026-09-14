/// Sections that are planned but not built. Listed in the nav on purpose so
/// the intranet's shape is visible from day one — and so nobody wonders
/// whether offers management was forgotten.
export function Placeholder({ title, note }: { title: string; note: string }) {
  return (
    <>
      <header>
        <h1>{title}</h1>
      </header>
      <div className="empty">{note}</div>
    </>
  );
}
