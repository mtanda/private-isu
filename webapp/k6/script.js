import http from 'k6/http';
import { check, sleep } from 'k6';
import { parseHTML } from 'k6/html';

const ACCOUNTS = (__ENV.ACCOUNTS || 'mary,patricia,linda,barbara,elizabeth').split(',');
const BASE_URL = __ENV.TARGET || 'http://nginx';
const POST_EVERY_N_ITERATIONS = Number(__ENV.POST_EVERY_N || 5);

const sampleImage = open('/userdata/img/00001.jpg', 'b');

export const options = {
  vus: Number(__ENV.VUS || 5),
  duration: __ENV.DURATION || '30s',
};

function pick(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

function csrfTokenOf(html) {
  return parseHTML(html).find('input[name="csrf_token"]').first().attr('value');
}

export default function () {
  const account = pick(ACCOUNTS);
  const password = account + account;

  const loginRes = http.post(`${BASE_URL}/login`, {
    account_name: account,
    password: password,
  });
  check(loginRes, { 'login succeeded': (r) => r.status === 200 });

  const indexRes = http.get(`${BASE_URL}/`);
  check(indexRes, { 'index loaded': (r) => r.status === 200 });
  const csrfToken = csrfTokenOf(indexRes.body);

  const postIDs = [...indexRes.body.matchAll(/\/posts\/(\d+)/g)].map((m) => m[1]);
  if (postIDs.length > 0) {
    const postID = pick(postIDs);

    const postRes = http.get(`${BASE_URL}/posts/${postID}`);
    check(postRes, { 'post detail loaded': (r) => r.status === 200 });

    const commentRes = http.post(`${BASE_URL}/comment`, {
      csrf_token: csrfToken,
      post_id: postID,
      comment: `nice ramen from k6 VU${__VU} iter${__ITER}`,
    });
    check(commentRes, { 'comment posted': (r) => r.status === 200 });
  }

  const accountRes = http.get(`${BASE_URL}/@${account}`);
  check(accountRes, { 'account page loaded': (r) => r.status === 200 });

  if (__ITER % POST_EVERY_N_ITERATIONS === 0) {
    const uploadRes = http.post(`${BASE_URL}/`, {
      csrf_token: csrfToken,
      body: `posting from k6 VU${__VU} iter${__ITER}`,
      file: http.file(sampleImage, '00001.jpg', 'image/jpeg'),
    });
    check(uploadRes, { 'post created': (r) => r.status === 200 });
  }

  sleep(1);
}
