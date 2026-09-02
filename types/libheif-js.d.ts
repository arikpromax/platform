/* Декодер HEIC (фото з iPhone). Пакет типів не постачає — описуємо те,
   чим користуємось: розмір картинки і малювання її в ImageData. */
declare module "libheif-js/wasm-bundle" {
  interface HeifImage {
    get_width(): number;
    get_height(): number;
    display(data: ImageData, cb: (result: ImageData | null) => void): void;
  }
  interface HeifDecoder {
    decode(buffer: Uint8Array): HeifImage[];
  }
  const libheif: { HeifDecoder: new () => HeifDecoder };
  export default libheif;
}
