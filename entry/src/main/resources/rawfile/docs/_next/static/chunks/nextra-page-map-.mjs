import meta from "../../../pages/_meta.js";
import basics_meta from "../../../pages/basics/_meta.js";
import historys_meta from "../../../pages/historys/_meta.js";
import scientific_meta from "../../../pages/scientific/_meta.js";
import support_meta from "../../../pages/support/_meta.js";
export const pageMap = [{
  data: meta
}, {
  name: "about",
  route: "/about",
  frontMatter: {
    "title": "关于"
  }
}, {
  name: "basics",
  route: "/basics",
  children: [{
    data: basics_meta
  }, {
    name: "arithmetic",
    route: "/basics/arithmetic",
    frontMatter: {
      "title": "加减乘除与括号优先级"
    }
  }, {
    name: "history",
    route: "/basics/history",
    frontMatter: {
      "title": "历史记录的查看与复用"
    }
  }, {
    name: "interface",
    route: "/basics/interface",
    frontMatter: {
      "title": "界面概览与按键分布"
    }
  }]
}, {
  name: "faq",
  route: "/faq",
  frontMatter: {
    "title": "常见问题解答"
  }
}, {
  name: "historys",
  route: "/historys",
  children: [{
    data: historys_meta
  }, {
    name: "interface",
    route: "/historys/interface",
    frontMatter: {
      "title": "界面概览与按键分布"
    }
  }]
}, {
  name: "index",
  route: "/",
  frontMatter: {
    "title": "介绍"
  }
}, {
  name: "scientific",
  route: "/scientific",
  children: [{
    data: scientific_meta
  }, {
    name: "algebra",
    route: "/scientific/algebra",
    frontMatter: {
      "title": "代数化简与因式分解"
    }
  }, {
    name: "calculus",
    route: "/scientific/calculus",
    frontMatter: {
      "title": "导数与定积分计算"
    }
  }, {
    name: "equations",
    route: "/scientific/equations",
    frontMatter: {
      "title": "一元二次、线性方程组求解"
    }
  }, {
    name: "exponents",
    route: "/scientific/exponents",
    frontMatter: {
      "title": "指数、对数与科学计数法"
    }
  }, {
    name: "fractions",
    route: "/scientific/fractions",
    frontMatter: {
      "title": "分数与小数的一键转换"
    }
  }, {
    name: "intro",
    route: "/scientific/intro",
    frontMatter: {
      "title": "CAS 引擎能力简介"
    }
  }, {
    name: "trigonometry",
    route: "/scientific/trigonometry",
    frontMatter: {
      "title": "三角函数"
    }
  }]
}, {
  name: "support",
  route: "/support",
  children: [{
    data: support_meta
  }, {
    name: "changelog",
    route: "/support/changelog",
    frontMatter: {
      "title": "版本更新日志"
    }
  }, {
    name: "privacy",
    route: "/support/privacy",
    frontMatter: {
      "title": "隐私声明"
    }
  }]
}];