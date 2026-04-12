import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'ZoomacIt',
  description: 'A native macOS menu bar app inspired by ZoomIt for Windows',

  head: [
    ['link', { rel: 'icon', href: '/images/icon-36.png' }],
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:title', content: 'ZoomacIt' }],
    ['meta', { property: 'og:description', content: 'A native macOS menu bar app inspired by ZoomIt for Windows — zoom, draw, and break timer' }],
    ['meta', { property: 'og:image', content: 'https://zoomacit.07jp27.net/images/banner.png' }],
    ['meta', { property: 'og:url', content: 'https://zoomacit.07jp27.net/' }],
  ],

  locales: {
    root: {
      label: 'English',
      lang: 'en',
      themeConfig: {
        nav: [
          { text: 'Installation', link: '/installation' },
          { text: 'Usage', link: '/usage' },
        ],
        sidebar: [
          {
            text: 'Guide',
            items: [
              { text: 'Installation', link: '/installation' },
              {
                text: 'Usage',
                link: '/usage',
                items: [
                  { text: 'Zoom', link: '/usage/zoom' },
                  { text: 'Draw', link: '/usage/draw' },
                  { text: 'Break Timer', link: '/usage/break-timer' },
                ],
              },
            ],
          },
        ],
      },
    },
    ja: {
      label: '日本語',
      lang: 'ja',
      description: 'Windows ZoomIt にインスパイアされたネイティブ macOS メニューバーアプリ',
      themeConfig: {
        nav: [
          { text: 'インストール', link: '/ja/installation' },
          { text: '使い方', link: '/ja/usage' },
        ],
        sidebar: [
          {
            text: 'ガイド',
            items: [
              { text: 'インストール', link: '/ja/installation' },
              {
                text: '使い方',
                link: '/ja/usage',
                items: [
                  { text: 'ズーム', link: '/ja/usage/zoom' },
                  { text: 'ドロー', link: '/ja/usage/draw' },
                  { text: '休憩タイマー', link: '/ja/usage/break-timer' },
                ],
              },
            ],
          },
        ],
        outline: { label: '目次' },
        docFooter: { prev: '前のページ', next: '次のページ' },
        lastUpdated: { text: '最終更新' },
        returnToTopLabel: 'トップに戻る',
        darkModeSwitchLabel: 'テーマ',
        langMenuLabel: '言語',
      },
    },
  },

  themeConfig: {
    logo: '/images/icon-36.png',

    socialLinks: [
      { icon: 'github', link: 'https://github.com/07JP27/ZoomacIt' },
      {
        icon: { svg: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" fill="currentColor"><path d="m8 14.25.345.666a.75.75 0 0 1-.69 0l-.008-.004-.018-.01a7.152 7.152 0 0 1-.31-.17 22.055 22.055 0 0 1-3.434-2.414C2.045 10.731 0 8.35 0 5.5 0 2.836 2.086 1 4.25 1 5.797 1 7.153 1.802 8 3.02 8.847 1.802 10.203 1 11.75 1 13.914 1 16 2.836 16 5.5c0 2.85-2.045 5.231-3.885 6.818a22.066 22.066 0 0 1-3.744 2.584l-.018.01-.006.003h-.002ZM4.25 2.5c-1.336 0-2.75 1.164-2.75 3 0 2.15 1.58 4.144 3.365 5.682A20.58 20.58 0 0 0 8 13.393a20.58 20.58 0 0 0 3.135-2.211C12.92 9.644 14.5 7.65 14.5 5.5c0-1.836-1.414-3-2.75-3-1.373 0-2.609.986-3.029 2.456a.749.749 0 0 1-1.442 0C6.859 3.486 5.623 2.5 4.25 2.5Z"/></svg>' },
        link: 'https://github.com/sponsors/07JP27',
        ariaLabel: 'Sponsor',
      },
    ],

    search: {
      provider: 'local',
    },

    footer: {
      message: 'Released under the GPL-3.0 License.',
      copyright: '© 2025 <a href="https://github.com/07JP27">07JP27</a>',
    },
  },
})
