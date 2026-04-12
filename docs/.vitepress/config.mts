import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'ZoomacIt',
  description: 'A native macOS menu bar app inspired by ZoomIt for Windows',

  head: [
    ['link', { rel: 'icon', href: '/images/icon-36.png' }],
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:title', content: 'ZoomacIt' }],
    ['meta', { property: 'og:description', content: 'A native macOS menu bar app inspired by ZoomIt for Windows — zoom, draw, and break timer' }],
    ['meta', { property: 'og:image', content: 'https://07jp27.net/images/banner.png' }],
    ['meta', { property: 'og:url', content: 'https://07jp27.net/' }],
  ],

  locales: {
    root: {
      label: 'English',
      lang: 'en',
      themeConfig: {
        nav: [
          { text: 'Installation', link: '/installation' },
          { text: 'Usage', link: '/usage' },
          { text: 'Shortcuts', link: '/shortcuts' },
        ],
        sidebar: [
          {
            text: 'Guide',
            items: [
              { text: 'Installation', link: '/installation' },
              { text: 'Usage', link: '/usage' },
              { text: 'Keyboard Shortcuts', link: '/shortcuts' },
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
          { text: 'ショートカット', link: '/ja/shortcuts' },
        ],
        sidebar: [
          {
            text: 'ガイド',
            items: [
              { text: 'インストール', link: '/ja/installation' },
              { text: '使い方', link: '/ja/usage' },
              { text: 'キーボードショートカット', link: '/ja/shortcuts' },
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
    ],

    search: {
      provider: 'local',
    },

    footer: {
      message: 'Released under the GPL-3.0 License.',
      copyright: '© 2025 ZoomacIt Contributors',
    },
  },
})
