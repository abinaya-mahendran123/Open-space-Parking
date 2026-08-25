/**
 * Convert PaddleOCR structured output to plain text for field parsers.
 */

function bboxTopLeft(bbox) {
  if (!Array.isArray(bbox) || bbox.length === 0) return [0, 0];
  const xs = bbox.map((p) => p[0]);
  const ys = bbox.map((p) => p[1]);
  return [Math.min(...ys), Math.min(...xs)];
}

function paddleLines(paddleResult) {
  if (!paddleResult || !Array.isArray(paddleResult.text)) return [];
  return paddleResult.text
    .filter((row) => row && row.text)
    .slice()
    .sort((a, b) => {
      const [ya, xa] = bboxTopLeft(a.bbox);
      const [yb, xb] = bboxTopLeft(b.bbox);
      if (Math.abs(ya - yb) > 12) return ya - yb;
      return xa - xb;
    });
}

function paddleResultToText(paddleResult) {
  return paddleLines(paddleResult)
    .map((row) => String(row.text || '').trim())
    .filter(Boolean)
    .join('\n');
}

function averageConfidence(paddleResult) {
  const lines = paddleLines(paddleResult);
  if (lines.length === 0) return 0;
  const sum = lines.reduce((acc, row) => acc + (Number(row.confidence) || 0), 0);
  return (sum / lines.length) * 100;
}

module.exports = {
  paddleLines,
  paddleResultToText,
  averageConfidence,
};
