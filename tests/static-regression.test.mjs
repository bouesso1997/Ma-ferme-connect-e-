import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const html = await readFile(new URL('../index.html', import.meta.url), 'utf8');

test('les six catégories de charges sont proposées', () => {
  for (const category of ['Alimentation', 'Prophylaxie', 'Salaires', 'Énergie', 'Logistique', 'Autres']) {
    assert.ok(html.includes(`<option value="${category}">${category}</option>`), `Catégorie absente : ${category}`);
  }
});

test('les dépenses anciennes sans catégorie restent classées Autres', () => {
  assert.match(html, /x\.category\|\|'Autres'/);
});

test('les totaux par catégorie sont calculés depuis les dépenses enregistrées', () => {
  assert.match(html, /id="expenseCategoryTotals"/);
  assert.match(html, /data\.expenses\.forEach\(x=>\{let c=x\.category\|\|'Autres'/);
});

test('la saisie des ventes refuse poids et montants non positifs', () => {
  assert.match(html, /Number\.isFinite\(weight\).*weight<=0.*Number\.isFinite\(amount\).*amount<=0/);
  assert.match(html, /id="saleWeight" type="number" min="0\.1"/);
  assert.match(html, /id="saleAmount" type="number" min="1"/);
});

test('la saisie des dépenses refuse un montant non positif', () => {
  assert.match(html, /Number\.isFinite\(amount\)\|\|amount<=0/);
  assert.match(html, /id="expAmount" type="number" min="1"/);
});

test('les données locales disposent toujours de leur mécanisme de sauvegarde', () => {
  assert.match(html, /localStorage\.getItem\(KEY/);
  assert.match(html, /localStorage\.setItem\(KEY,JSON\.stringify\(data\)\)/);
});

test('l’envoi général vers le serveur reste désactivé tant que la synchronisation n’est pas validée', () => {
  assert.match(html, /id="cloudPush"[^>]*disabled|id="cloudPush" class="secondary" type="button">Envoi général temporairement désactivé/);
});
