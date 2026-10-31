import type { Register } from 'claude-code'

import { BADGE_HEIGHT, BADGE_INK, BADGE_MARK, BADGE_NAME, BADGE_SUB, BADGE_SVG, BADGE_WIDTH } from './badge'

export const register: Register = on => {
  on('ui.render', { component: 'AbovePrompt' }, ($, e, next) => {
    if (e.props.hasSurvey) {
      return next(e)
    }

    if (e.surface === 'terminal') {
      const { Box, Text } = $.ui.resolve(e)

      return (
        <Box gap={1}>
          <Text color={BADGE_MARK}>■</Text>
          <Text color={BADGE_INK} weight="bold">{BADGE_NAME}</Text>
          <Text dimColor>{BADGE_SUB}</Text>
        </Box>
      )
    }

    const { Box, Svg } = $.ui.resolve(e)

    return (
      <Box>
        <Svg
          source={BADGE_SVG}
          alt={`${BADGE_NAME}, ${BADGE_SUB}`}
          width={BADGE_WIDTH}
          height={BADGE_HEIGHT}
        />
      </Box>
    )
  })
}
