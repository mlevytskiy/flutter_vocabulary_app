// The Worker's view of `page.js`: wrangler bundles it as a Text module
// (wrangler.jsonc `rules`), so importing it yields the script's source.
declare const script: string;
export default script;
