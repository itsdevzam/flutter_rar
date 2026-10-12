import 'dart:convert';
import 'dart:typed_data';

/// RAR5 archive with encrypted headers (`rar -hpsecret`).
/// Entries: hello.txt, lorem.txt, nested/notes.txt.
final Uint8List sampleRar = base64Decode(
  'UmFyIRoHAQABoG2gIQQAAAEPQ+Y3H94N1esE9QAHoSnGi5lPbMGkTZD+e2lB8mFtr/eXiZ7qNL2Z'
  '6END7Wjdv75N1W14NN/LDFZ4jhLG0N8hsna8f4d2x62Oa46K9jmvYV6nTS35znUAwCZ0uQakIlKZ'
  'qSF5PshlkZM/30/9hXP+RIDYIHHpLv6eANAkInTJsIUc3qjoUvUQT4BDhCvXb09yoJR4LyBvkjmd'
  'YgQlW49NskR1QEwL9gDNha4VhyZ0dZ3lntVHJUFHTdyrQncbFVg3Y5BvosydxwM9h3zL6A7LjWfM'
  'eqAw8bct3Ga5ltC9e7X02+0OoIXR7nN1p9XakrMrseBCWKwTDqHHoNLruv8b+jch8eeuUBzLz5fp'
  'BDMQItieJT9Kk5x1Hq4tk8lhGVNCldUup3lRK0BEULNdG0dv8L8JzDhdR6pDH+UxTOX56veahdBF'
  'tnOCKK1iKxlbwk1cFsNkRUbjBDg/dw48hlvfAhyICxejgjNwUSShMf5oYF86gWVsXHEtDXJRGLf1'
  'KK2Vz9kokE7QWjkVAaMZ1hMinzPqBeaZt24TtEIHUkSOvR7C28U4dyD3dGHY2xek2Wx6jr20dIhB'
  'Dw6pKLzeGbsP1DxxdHqbeaP/2S/CzlGnpEMCUrYC9qHkjAIfaTMwfLXf3T9/04AMnCVuMCioY0u9'
  'UnWqdEEkHGSPgY1151W4K/yJUAGEOOJC3Y4b/iUVZawx99LAWILEDf39s4J6qlROU7cLRT+V05LL'
  '7S2hR3EkwRNEk7yJRQXuj6v2PbhiDvEC4W+Ao3p0gcRk2gc+',
);

const samplePassword = 'secret';

const sampleFiles = {
  'hello.txt': 'hello, encrypted headers!\n',
  'lorem.txt':
      'lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor\n',
  'nested/notes.txt': 'deep nested data\n',
};
