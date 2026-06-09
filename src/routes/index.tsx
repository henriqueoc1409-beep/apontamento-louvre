import { createFileRoute } from "@tanstack/react-router";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "Apontamento de Obra — Louvre | Três Incorporadora" },
      { name: "description", content: "Sistema de apontamento de obra do empreendimento Louvre — Três Incorporadora." },
      { property: "og:title", content: "Apontamento de Obra — Louvre" },
      { property: "og:description", content: "Sistema de apontamento de obra do empreendimento Louvre — Três Incorporadora." },
    ],
  }),
  component: Index,
});

function Index() {
  return (
    <iframe
      src="/apontamento.html"
      title="Apontamento de Obra — Louvre"
      style={{ border: 0, width: "100vw", height: "100vh", display: "block" }}
    />
  );
}
